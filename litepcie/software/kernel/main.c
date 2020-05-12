// This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

/*
 * LitePCIe driver
 *
 */
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/ioctl.h>
#include <linux/init.h>
#include <linux/errno.h>
#include <linux/mm.h>
#include <linux/fs.h>
#include <linux/mmtimer.h>
#include <linux/miscdevice.h>
#include <linux/posix-timers.h>
#include <linux/interrupt.h>
#include <linux/time.h>
#include <linux/math64.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/pci.h>
#include <linux/pci_regs.h>
#include <linux/cdev.h>
#include <linux/delay.h>
#include <linux/wait.h>
#include <linux/version.h>
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 11, 0)
#include <linux/sched/signal.h>
#endif


#include "litepcie.h"
#include "config.h"
#include "csr.h"
#include "soc.h"
#include "flags.h"

#define LITEPCIE_NAME "litepcie"
#define LITEPCIE_MINOR_COUNT 4

#define DMA_BUFFER_SIZE PAGE_ALIGN(32768)
#define DMA_BUFFER_MAP_SIZE (DMA_BUFFER_SIZE * PCIE_DMA_BUFFER_COUNT)

#define IRQ_MASK_PCIE_DMA_READER (1 << PCIE_DMA_READER_INTERRUPT)
#define IRQ_MASK_PCIE_DMA_WRITER (1 << PCIE_DMA_WRITER_INTERRUPT)

typedef struct {
    int minor;
    struct pci_dev *dev;
    struct cdev cdev_struct;

    phys_addr_t bar0_phys_addr;
    uint8_t *bar0_addr; /* virtual address of BAR0 */

    uint8_t *dma_tx_bufs[PCIE_DMA_BUFFER_COUNT];
    unsigned long dma_tx_bufs_addr[PCIE_DMA_BUFFER_COUNT];
    uint8_t *dma_rx_bufs[PCIE_DMA_BUFFER_COUNT];
    unsigned long dma_rx_bufs_addr[PCIE_DMA_BUFFER_COUNT];
    uint8_t tx_dma_started;
    uint8_t rx_dma_started;
    wait_queue_head_t dma_waitqueue;
} LitePCIeState;

static dev_t litepcie_cdev;
static LitePCIeState *litepcie_minor_table[LITEPCIE_MINOR_COUNT];
static struct class *litepcie_class;

static void litepcie_end(struct pci_dev *dev, LitePCIeState *s);
static int litepcie_dma_stop(LitePCIeState *s);

static inline uint32_t litepcie_readl(LitePCIeState *s, uint32_t addr)
{
    return readl(s->bar0_addr + addr);
}

static inline void litepcie_writel(LitePCIeState *s, uint32_t addr, uint32_t val)
{
    return writel(val, s->bar0_addr + addr);
}

static void litepcie_enable_interrupt(LitePCIeState *s, int irq_num)
{
    uint32_t v;
    v = litepcie_readl(s, CSR_PCIE_MSI_ENABLE_ADDR);
    v |= (1 << irq_num);
    litepcie_writel(s, CSR_PCIE_MSI_ENABLE_ADDR, v);
}

static void litepcie_disable_interrupt(LitePCIeState *s, int irq_num)
{
    uint32_t v;
    v = litepcie_readl(s, CSR_PCIE_MSI_ENABLE_ADDR);
    v &= ~(1 << irq_num);
    litepcie_writel(s, CSR_PCIE_MSI_ENABLE_ADDR, v);
}

static int litepcie_open(struct inode *inode, struct file *file)
{
    LitePCIeState *s;

    s = container_of(inode->i_cdev, LitePCIeState, cdev_struct);
    if (!s)
        return -ENODEV;
    file->private_data = s;
    return 0;
}

/* mmap the DMA buffers and registers to user space */
static int litepcie_mmap(struct file *file, struct vm_area_struct *vma)
{
    LitePCIeState *s = file->private_data;
    unsigned long pfn;
    int is_tx, i;

    if (vma->vm_pgoff == 0) {
        if (vma->vm_end - vma->vm_start != DMA_BUFFER_MAP_SIZE)
            return -EINVAL;
        is_tx = 1;
        goto remap_ram;
    } else if (vma->vm_pgoff == (DMA_BUFFER_MAP_SIZE >> PAGE_SHIFT)) {
        if (vma->vm_end - vma->vm_start != DMA_BUFFER_MAP_SIZE)
            return -EINVAL;
        is_tx = 0;
    remap_ram:
        for(i = 0; i < PCIE_DMA_BUFFER_COUNT; i++) {
            if (is_tx)
                pfn = __pa(s->dma_tx_bufs[i]) >> PAGE_SHIFT;
            else
                pfn = __pa(s->dma_rx_bufs[i]) >> PAGE_SHIFT;
            /* Note: the memory is cached, so the user must explicitly
               flush the CPU caches on architectures which require it. */
            if (remap_pfn_range(vma, vma->vm_start + i * DMA_BUFFER_SIZE, pfn,
                                DMA_BUFFER_SIZE, vma->vm_page_prot)) {
                pr_err("remap_pfn_range failed\n");
                return -EAGAIN;
            }
        }
    } else if (vma->vm_pgoff == ((2 * DMA_BUFFER_MAP_SIZE) >> PAGE_SHIFT)) {
        if (vma->vm_end - vma->vm_start != PCI_FPGA_BAR0_SIZE)
            return -EINVAL;
        pfn = s->bar0_phys_addr >> PAGE_SHIFT;
        /* not cached */
        vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
        vma->vm_flags |= VM_IO;
        if (io_remap_pfn_range(vma, vma->vm_start, pfn,
                               vma->vm_end - vma->vm_start,
                               vma->vm_page_prot)) {
            pr_err("io_remap_pfn_range failed\n");
            return -EAGAIN;
        }
    } else {
        return -EINVAL;
    }

    return 0;
}

static int litepcie_release(struct inode *inode, struct file *file)
{
    LitePCIeState *s = file->private_data;

    litepcie_dma_stop(s); /* just in case: stop the DMA */
    return 0;
}

static irqreturn_t litepcie_interrupt(int irq, void *data)
{
    LitePCIeState *s = data;
    uint32_t clear_mask, irq_vector;

    irq_vector = litepcie_readl(s, CSR_PCIE_MSI_VECTOR_ADDR);
    clear_mask = 0;
    if (irq_vector & (IRQ_MASK_PCIE_DMA_READER | IRQ_MASK_PCIE_DMA_WRITER)) {
        /* wake up processes waiting on dma_wait() */
        wake_up_interruptible(&s->dma_waitqueue);
        clear_mask |= (IRQ_MASK_PCIE_DMA_READER | IRQ_MASK_PCIE_DMA_WRITER);
    }

    litepcie_writel(s, CSR_PCIE_MSI_CLEAR_ADDR, clear_mask);

    return IRQ_HANDLED;
}

static int litepcie_dma_start(LitePCIeState *s, struct litepcie_ioctl_dma_start *m)
{
    int i, val;

    if (s->tx_dma_started || s->rx_dma_started)
        return -EIO;

    if (m->tx_buf_size == 0 && m->rx_buf_size == 0)
        return -EINVAL;
    /* check alignment (XXX: what is the exact constraint ?) */
    if ((m->tx_buf_size & 7) != 0 ||
        (m->rx_buf_size & 7) != 0 ||
        m->tx_buf_size > DMA_BUFFER_SIZE ||
        m->rx_buf_size > DMA_BUFFER_SIZE)
        return -EINVAL;

    /* check buffer count */
    if (m->tx_buf_count > PCIE_DMA_BUFFER_COUNT)
       return -EINVAL;
    if (m->rx_buf_count > PCIE_DMA_BUFFER_COUNT)
        return -EINVAL;

    val = ((m->dma_flags & PCIE_DMA_LOOPBACK_ENABLE) != 0);
    litepcie_writel(s, CSR_PCIE_DMA_LOOPBACK_ENABLE_ADDR, val);

    /* init DMA write */
    if (m->rx_buf_size != 0) {
        litepcie_writel(s, CSR_PCIE_DMA_WRITER_ENABLE_ADDR, 0);
        litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_FLUSH_ADDR, 1);
        litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_LOOP_PROG_N_ADDR, 0);
        for(i = 0; i < m->rx_buf_count; i++) {
            litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_VALUE_ADDR, m->rx_buf_size);
            litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_VALUE_ADDR + 4,
                       s->dma_rx_bufs_addr[i]);
            litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_WE_ADDR, 1);
        }
        litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_LOOP_PROG_N_ADDR, 1);
    }

    /* init DMA read */
    if (m->tx_buf_size != 0) {
        litepcie_writel(s, CSR_PCIE_DMA_READER_ENABLE_ADDR, 0);
        litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_FLUSH_ADDR, 1);
        litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_LOOP_PROG_N_ADDR, 0);
        for(i = 0; i < m->tx_buf_count; i++) {
            litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_VALUE_ADDR, m->tx_buf_size);
            litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_VALUE_ADDR + 4,
                       s->dma_tx_bufs_addr[i]);
            litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_WE_ADDR, 1);
        }
        litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_LOOP_PROG_N_ADDR, 1);
    }

    /* start DMA */
    if (m->rx_buf_size != 0) {
        litepcie_writel(s, CSR_PCIE_DMA_WRITER_ENABLE_ADDR, 1);
        s->rx_dma_started = 1;
    }
    if (m->tx_buf_size != 0) {
        litepcie_writel(s, CSR_PCIE_DMA_READER_ENABLE_ADDR, 1);
        s->tx_dma_started = 1;
    }

    return 0;
}

static int litepcie_dma_wait(LitePCIeState *s, struct litepcie_ioctl_dma_wait *m)
{
    unsigned long timeout;
    int ret, last_buf_num;
    DECLARE_WAITQUEUE(wait, current);

    if (m->tx_wait) {
        if (!s->tx_dma_started)
            return -EIO;
        last_buf_num = m->tx_buf_num;
        litepcie_enable_interrupt(s, PCIE_DMA_READER_INTERRUPT);
    } else {
        if (!s->rx_dma_started)
            return -EIO;
        last_buf_num = m->rx_buf_num;
        litepcie_enable_interrupt(s, PCIE_DMA_WRITER_INTERRUPT);
    }

    add_wait_queue(&s->dma_waitqueue, &wait);

    timeout = jiffies + msecs_to_jiffies(m->timeout);
    for (;;) {
        /* set current buffer */
        if (s->tx_dma_started) {
            m->tx_buf_num = (litepcie_readl(s, CSR_PCIE_DMA_READER_TABLE_LOOP_STATUS_ADDR) & 0xffff);
        } else {
            m->tx_buf_num = 0;
        }
        if (s->rx_dma_started) {
            m->rx_buf_num = (litepcie_readl(s, CSR_PCIE_DMA_WRITER_TABLE_LOOP_STATUS_ADDR) & 0xffff);
        } else {
            m->rx_buf_num = 0;
        }
        if (m->tx_wait) {
            if (m->tx_buf_num != last_buf_num)
                break;
        } else {
            if (m->rx_buf_num != last_buf_num)
                break;
        }
        if ((long)(jiffies - timeout) > 0) {
            ret = -EAGAIN;
            goto done;
        }
        set_current_state(TASK_INTERRUPTIBLE);
        if (signal_pending(current)) {
            ret = -EINTR;
            goto done;
        }
        schedule();
    }
    ret = 0;
 done:
    if (m->tx_wait) {
        litepcie_disable_interrupt(s, PCIE_DMA_READER_INTERRUPT);
    } else {
        litepcie_disable_interrupt(s, PCIE_DMA_WRITER_INTERRUPT);
    }

    __set_current_state(TASK_RUNNING);
    remove_wait_queue(&s->dma_waitqueue, &wait);
    return ret;
}

static int litepcie_dma_stop(LitePCIeState *s)
{
    /* just to be sure, we disable the interrupts */
    litepcie_disable_interrupt(s, PCIE_DMA_READER_INTERRUPT);
    litepcie_disable_interrupt(s, PCIE_DMA_WRITER_INTERRUPT);

    s->tx_dma_started = 0;
    litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_LOOP_PROG_N_ADDR, 0);
    litepcie_writel(s, CSR_PCIE_DMA_READER_TABLE_FLUSH_ADDR, 1);
    udelay(100);
    litepcie_writel(s, CSR_PCIE_DMA_READER_ENABLE_ADDR, 0);

    s->rx_dma_started = 0;
    litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_LOOP_PROG_N_ADDR, 0);
    litepcie_writel(s, CSR_PCIE_DMA_WRITER_TABLE_FLUSH_ADDR, 1);
    udelay(100);
    litepcie_writel(s, CSR_PCIE_DMA_WRITER_ENABLE_ADDR, 0);

    return 0;
}

static long litepcie_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    LitePCIeState *s = file->private_data;
    long ret;

    switch(cmd) {
    case LITEPCIE_IOCTL_GET_MMAP_INFO:
        {
            struct litepcie_ioctl_mmap_info m;
            m.dma_tx_buf_offset = 0;
            m.dma_tx_buf_size = DMA_BUFFER_SIZE;
            m.dma_tx_buf_count = PCIE_DMA_BUFFER_COUNT;

            m.dma_rx_buf_offset = DMA_BUFFER_MAP_SIZE;
            m.dma_rx_buf_size = DMA_BUFFER_SIZE;
            m.dma_rx_buf_count = PCIE_DMA_BUFFER_COUNT;

            m.reg_offset = 2 * DMA_BUFFER_MAP_SIZE;
            m.reg_size = PCI_FPGA_BAR0_SIZE;
            if (copy_to_user((void *)arg, &m, sizeof(m))) {
                ret = -EFAULT;
                break;
            }
            ret = 0;
        }
        break;
    case LITEPCIE_IOCTL_DMA_START:
        {
            struct litepcie_ioctl_dma_start m;

            if (copy_from_user(&m, (void *)arg, sizeof(m))) {
                ret = -EFAULT;
                break;
            }
            ret = litepcie_dma_start(s, &m);
        }
        break;
    case LITEPCIE_IOCTL_DMA_STOP:
        {
            ret = litepcie_dma_stop(s);
        }
        break;
    case LITEPCIE_IOCTL_DMA_WAIT:
        {
            struct litepcie_ioctl_dma_wait m;

            if (copy_from_user(&m, (void *)arg, sizeof(m))) {
                ret = -EFAULT;
                break;
            }
            ret = litepcie_dma_wait(s, &m);
            if (ret == 0) {
                if (copy_to_user((void *)arg, &m, sizeof(m))) {
                    ret = -EFAULT;
                    break;
                }
            }
        }
        break;
    default:
        ret = -ENOIOCTLCMD;
        break;
    }
    return ret;
}

static const struct file_operations litepcie_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = litepcie_ioctl,
	.open = litepcie_open,
	.release = litepcie_release,
    .mmap = litepcie_mmap,
	.llseek = no_llseek,
};

static int litepcie_pci_probe(struct pci_dev *dev, const struct pci_device_id *id)
{
    LitePCIeState *s = NULL;
    uint8_t rev_id;
    int ret, minor, i;
    struct device *clsdev;

    dev_info(&dev->dev, "Probing device\n");

    s = devm_kzalloc(&dev->dev, sizeof(LitePCIeState), GFP_KERNEL);
    if (!s)
        return -ENOMEM;

    /* find available minor */
    for(minor = 0; minor < LITEPCIE_MINOR_COUNT; minor++) {
        if (!litepcie_minor_table[minor])
            break;
    }
    if (minor == LITEPCIE_MINOR_COUNT) {
        dev_err(&dev->dev, "Cannot allocate a minor\n");
        return -ENODEV;
    }

    s->minor = minor;
    s->dev = dev;
    pci_set_drvdata(dev, s);

    cdev_init(&s->cdev_struct, &litepcie_fops);
    s->cdev_struct.owner = THIS_MODULE;
    ret = cdev_add(&s->cdev_struct, MKDEV(MAJOR(litepcie_cdev), minor), 1);
    if (ret) {
        dev_err(&dev->dev, "Could not register char device\n");
        return ret;
    }

    clsdev = device_create(litepcie_class, NULL,
                           MKDEV(MAJOR(litepcie_cdev), minor),
                           NULL, LITEPCIE_NAME "%d", minor);
    if (IS_ERR(clsdev)) {
        dev_err(&dev->dev, "device_create\n");
        ret = -PTR_ERR(clsdev);
        goto fail_dev_create;
    }

    ret = pcim_enable_device(dev);
    if (ret != 0) {
        dev_err(&dev->dev, "Cannot enable device\n");
        goto fail1;
    }

    /* check device version */
    pci_read_config_byte(dev, PCI_REVISION_ID, &rev_id);
    if (rev_id != 1) {
        dev_err(&dev->dev, "Unsupported device version %d\n", rev_id);
        goto fail2;
    }

    if (pci_request_regions(dev, LITEPCIE_NAME) < 0) {
        dev_err(&dev->dev, "Could not request regions\n");
        goto fail2;
    }

    /* check BAR0 config */
    if (!(pci_resource_flags(dev, 0) & IORESOURCE_MEM)) {
        dev_err(&dev->dev, "Invalid BAR0 config\n");
        goto fail3;
    }

    s->bar0_phys_addr = pci_resource_start(dev, 0);
    s->bar0_addr = pci_ioremap_bar(dev, 0);
    if (!s->bar0_addr) {
        dev_err(&dev->dev, "Could not map BAR0\n");
        goto fail3;
    }

    pci_set_master(dev);
    ret = pci_set_dma_mask(dev, DMA_BIT_MASK(32));
    if (ret) {
        dev_err(&dev->dev, "Failed to set DMA mask\n");
        goto fail4;
    };

    ret = pci_enable_msi(dev);
    if (ret) {
        dev_err(&dev->dev, "Failed to enable MSI\n");
        goto fail4;
    }

    if (devm_request_irq(&dev->dev, dev->irq, litepcie_interrupt,
                         IRQF_SHARED, LITEPCIE_NAME, s) < 0) {
        dev_err(&dev->dev, "Failed to allocate irq %d\n", dev->irq);
        goto fail4;
    }

    /* soft reset */
    litepcie_writel(s, CSR_CRG_RST_ADDR, 1);
    udelay(1000);

    /* allocate DMA buffers */
    for(i = 0; i < PCIE_DMA_BUFFER_COUNT; i++) {
        s->dma_tx_bufs[i] = kzalloc(DMA_BUFFER_SIZE, GFP_KERNEL | GFP_DMA32);
        if (!s->dma_tx_bufs[i]) {
            goto fail6;
        }
        s->dma_tx_bufs_addr[i] = pci_map_single(dev, s->dma_tx_bufs[i],
                                                DMA_BUFFER_SIZE,
                                                DMA_TO_DEVICE);
        if (!s->dma_tx_bufs_addr[i]) {
            ret = -ENOMEM;
            goto fail6;
        }
    }

    for(i = 0; i < PCIE_DMA_BUFFER_COUNT; i++) {
        s->dma_rx_bufs[i] = kzalloc(DMA_BUFFER_SIZE, GFP_KERNEL | GFP_DMA32);
        if (!s->dma_rx_bufs[i]) {
            goto fail6;
        }

        s->dma_rx_bufs_addr[i] = pci_map_single(dev, s->dma_rx_bufs[i],
                                                DMA_BUFFER_SIZE,
                                                DMA_FROM_DEVICE);
        if (!s->dma_rx_bufs_addr[i]) {
            ret = -ENOMEM;
            goto fail6;
        }
    }

    init_waitqueue_head(&s->dma_waitqueue);

    litepcie_minor_table[minor] = s;
    dev_info(&dev->dev, "Assigned to minor %d\n", minor);
    return 0;

 fail6:
    litepcie_end(dev, s);
 fail4:
    pci_iounmap(dev, s->bar0_addr);
 fail3:
    pci_release_regions(dev);
 fail2:
    ret = -EIO;
 fail1:
    device_destroy(litepcie_class, MKDEV(MAJOR(litepcie_cdev), minor));
 fail_dev_create:
    cdev_del(&s->cdev_struct);
    dev_err(&dev->dev, "Error while probing device\n");
    return ret;
}

static void litepcie_end(struct pci_dev *dev, LitePCIeState *s)
{
    int i;

    for(i = 0; i < PCIE_DMA_BUFFER_COUNT; i++) {
        if (s->dma_tx_bufs_addr[i]) {
            dma_unmap_single(&dev->dev, s->dma_tx_bufs_addr[i],
                             DMA_BUFFER_SIZE, DMA_TO_DEVICE);
        }
        kfree(s->dma_tx_bufs[i]);
    }

    for(i = 0; i < PCIE_DMA_BUFFER_COUNT; i++) {
        if (s->dma_rx_bufs_addr[i]) {
            dma_unmap_single(&dev->dev, s->dma_rx_bufs_addr[i],
                             DMA_BUFFER_SIZE, DMA_FROM_DEVICE);
        }
        kfree(s->dma_rx_bufs[i]);
    }
}

static void litepcie_pci_remove(struct pci_dev *dev)
{
    LitePCIeState *s = pci_get_drvdata(dev);

    dev_info(&dev->dev, "Removing device\n");
    litepcie_minor_table[s->minor] = NULL;

    litepcie_end(dev, s);
    pci_iounmap(dev, s->bar0_addr);
    device_destroy(litepcie_class, MKDEV(MAJOR(litepcie_cdev), s->minor));
    cdev_del(&s->cdev_struct);
	/* There is no need to call pci_release_regions() as it is handled
	 * by the kernel since we used pcim_enable_device() */
};

static const struct pci_device_id litepcie_pci_ids[] = {
    { PCI_DEVICE(PCI_FPGA_VENDOR_ID, PCI_FPGA_DEVICE_ID_X1 ), },
    { PCI_DEVICE(PCI_FPGA_VENDOR_ID, PCI_FPGA_DEVICE_ID_X2 ), },
    { PCI_DEVICE(PCI_FPGA_VENDOR_ID, PCI_FPGA_DEVICE_ID_X4 ), },
    { PCI_DEVICE(PCI_FPGA_VENDOR_ID, PCI_FPGA_DEVICE_ID_X8 ), },
    { 0, }
};
MODULE_DEVICE_TABLE(pci, litepcie_pci_ids);


static struct pci_driver litepcie_pci_driver = {
	.name = LITEPCIE_NAME,
	.id_table = litepcie_pci_ids,
	.probe = litepcie_pci_probe,
	.remove = litepcie_pci_remove,
};

static int __init litepcie_module_init(void)
{
    int	ret;

    ret = alloc_chrdev_region(&litepcie_cdev, 0, LITEPCIE_MINOR_COUNT, LITEPCIE_NAME);
    if (ret < 0) {
        pr_err("Could not allocate char device\n");
        return ret;
    }

    litepcie_class = class_create(THIS_MODULE, LITEPCIE_NAME);
    if (IS_ERR(litepcie_class)) {
        pr_err("Error creating class\n");
        ret = PTR_ERR(litepcie_class);
        goto fail_class;
    }

    ret = pci_register_driver(&litepcie_pci_driver);
    if (ret < 0) {
        pr_err("Error while registering PCI driver\n");
        goto fail_register;
    }

    return 0;

 fail_register:
    class_destroy(litepcie_class);
 fail_class:
 	unregister_chrdev_region(litepcie_cdev, LITEPCIE_MINOR_COUNT);

    return ret;
}

static void __exit litepcie_module_exit(void)
{
    pci_unregister_driver(&litepcie_pci_driver);
    class_destroy(litepcie_class);
    unregister_chrdev_region(litepcie_cdev, LITEPCIE_MINOR_COUNT);
}


module_init(litepcie_module_init);
module_exit(litepcie_module_exit);

MODULE_LICENSE("GPL");
