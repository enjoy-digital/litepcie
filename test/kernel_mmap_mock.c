/* Compile the actual driver mmap function against a narrow DMA API mock. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define KERNEL_VERSION(a, b, c) (((a) << 16) | ((b) << 8) | (c))
#define DMA_BUFFER_SIZE 8192UL
#define DMA_BUFFER_COUNT 4
#define DMA_BUFFER_TOTAL_SIZE (DMA_BUFFER_SIZE * DMA_BUFFER_COUNT)
#define PAGE_SHIFT 12
#define VM_IO 1UL
#define VM_PFNMAP 2UL
#define VM_MIXEDMAP 4UL
#define VM_DONTEXPAND 8UL
#define VM_DONTDUMP 16UL
#define ORIGINAL_FLAGS 0x100UL
#define dev_err(...) ((void)0)

typedef unsigned long dma_addr_t;
struct device { int unused; };
struct pci_dev { struct device dev; };
struct litepcie_device { struct pci_dev *dev; };
struct litepcie_chan {
    struct litepcie_device *litepcie_dev;
    struct {
        void *reader_addr[DMA_BUFFER_COUNT], *writer_addr[DMA_BUFFER_COUNT];
        dma_addr_t reader_handle[DMA_BUFFER_COUNT], writer_handle[DMA_BUFFER_COUNT];
    } dma;
};
struct litepcie_chan_priv { struct litepcie_chan *chan; };
struct file { void *private_data; };
struct vm_area_struct {
    unsigned long vm_start, vm_end, vm_pgoff, vm_flags, vm_page_prot;
};

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 3, 0)
static inline void vm_flags_set(struct vm_area_struct *vma, unsigned long flags)
{
    vma->vm_flags |= flags;
}
#endif

/* Also allow the current upstream function's removal guard. */
#define litepcie_enter(s) ((void)(s), true)
#define litepcie_exit(s) ((void)(s))
static int calls, fail_at, direction;
static unsigned long mapping_flags;
static struct vm_area_struct *parent;
static struct litepcie_chan *channel;

static int dma_mmap_coherent(struct device *dev, struct vm_area_struct *vma,
                            void *cpu_addr, dma_addr_t handle, unsigned long size)
{
    (void)dev;
    assert(size == DMA_BUFFER_SIZE);
    assert((parent->vm_flags & (VM_DONTEXPAND | VM_DONTDUMP)) == (VM_DONTEXPAND | VM_DONTDUMP));
    assert(vma->vm_start == parent->vm_start + calls * DMA_BUFFER_SIZE);
    assert(vma->vm_end == vma->vm_start + DMA_BUFFER_SIZE);
    assert(vma->vm_pgoff == 0);
    assert(cpu_addr == (direction ? channel->dma.reader_addr[calls] : channel->dma.writer_addr[calls]));
    assert(handle == (direction ? channel->dma.reader_handle[calls] : channel->dma.writer_handle[calls]));
    vma->vm_flags |= mapping_flags;
    vma->vm_page_prot = 0x77;
    /* Even a failed mapping may have installed some PTEs. */
    return calls++ == fail_at ? -EAGAIN : 0;
}

/* DRIVER_MMAP */

int main(void)
{
    struct pci_dev pci = {0};
    struct litepcie_device device = {.dev=&pci};
    struct litepcie_chan chan = {.litepcie_dev=&device};
    struct litepcie_chan_priv priv = {.chan=&chan};
    struct file file = {.private_data=&priv};
    for (int i = 0; i < DMA_BUFFER_COUNT; i++) {
        chan.dma.reader_addr[i] = (void *)(uintptr_t)(0x100000 + i * DMA_BUFFER_SIZE);
        chan.dma.writer_addr[i] = (void *)(uintptr_t)(0x200000 + i * DMA_BUFFER_SIZE);
        chan.dma.reader_handle[i] = 0x300000 + i * DMA_BUFFER_SIZE;
        chan.dma.writer_handle[i] = 0x400000 + i * DMA_BUFFER_SIZE;
    }
    channel = &chan;
    struct vm_area_struct invalid = {.vm_start=0x1000000,
        .vm_end=0x1000000 + DMA_BUFFER_TOTAL_SIZE - 1, .vm_flags=ORIGINAL_FLAGS};
    calls = 0;
    assert(litepcie_mmap(&file, &invalid) == -EINVAL && calls == 0);
    invalid.vm_end++;
    invalid.vm_pgoff = 1;
    assert(litepcie_mmap(&file, &invalid) == -EINVAL && calls == 0);
    for (int kind = 0; kind < 2; kind++) {
        mapping_flags = kind ? VM_MIXEDMAP : VM_IO | VM_PFNMAP | VM_DONTEXPAND | VM_DONTDUMP;
        for (direction = 0; direction < 2; direction++) {
            for (fail_at = -1; fail_at < DMA_BUFFER_COUNT; fail_at++) {
                struct vm_area_struct vma = {.vm_start=0x1000000,
                    .vm_end=0x1000000 + DMA_BUFFER_TOTAL_SIZE,
                    .vm_pgoff=direction ? 0 : DMA_BUFFER_TOTAL_SIZE >> PAGE_SHIFT,
                    .vm_flags=ORIGINAL_FLAGS, .vm_page_prot=0x33};
                struct vm_area_struct before = vma;
                parent = &vma;
                calls = 0;
                assert(litepcie_mmap(&file, &vma) == (fail_at < 0 ? 0 : -EAGAIN));
                assert(calls == (fail_at < 0 ? DMA_BUFFER_COUNT : fail_at + 1));
                assert(vma.vm_start == before.vm_start && vma.vm_end == before.vm_end);
                assert(vma.vm_pgoff == before.vm_pgoff);
                assert(vma.vm_flags == (ORIGINAL_FLAGS | mapping_flags | VM_DONTEXPAND | VM_DONTDUMP));
                assert(vma.vm_page_prot == 0x77);
            }
        }
    }
    return 0;
}
