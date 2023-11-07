#!/bin/sh
# TODO: use udev instead

# Check if litepcie module is already installed.
FOUND=$(lsmod | grep litepcie)
if [ "$FOUND" != "" ] ; then
    echo "litepcie module already installed."
    exit 0
fi

# Automatically remove liteuart module if installed.
FOUND=$(lsmod | grep liteuart)
if [ "$FOUND" != "" ] ; then
    rmmod liteuart.ko
fi

# Install litepcie module.
INS=$(insmod litepcie.ko 2>&1)
if [ "$?" != "0" ] ; then
    ERR=$(echo $INS | sed -s "s/.*litepcie.ko: //")
    case $ERR in
    'Invalid module format')
        set -e
        echo "Kernel may have changed, try to rebuild module"
        make -s clean
        make -s
        insmod litepcie.ko
        set +e
        ;;
    'No such file or directory')
        set -e
        echo "Module not compiled"
        make -s
        insmod litepcie.ko
        set +e
        ;;
    'Required key not available')
        echo "Can't insert kernel module, secure boot is probably enabled"
        echo "Please disable it from BIOS"
        exit 1
        ;;
    *)
        >&2 echo $INS
        exit 1
    esac
fi

# Install liteuart module.
insmod liteuart.ko

# Change permissions on litepcie created devices.
for i in `seq 0 16` ; do
    chmod 666 /dev/litepcie$i > /dev/null 2>&1
done

