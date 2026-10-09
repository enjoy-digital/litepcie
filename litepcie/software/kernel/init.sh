#!/bin/sh
# TODO: use udev instead

# Driver/device name: $NAME.ko module, /dev/$NAMEN devices.
NAME=${LITEPCIE_NAME:-litepcie}

# Check if litepcie module is already installed.
FOUND=$(lsmod | grep "^$NAME ")
if [ "$FOUND" != "" ] ; then
    echo "$NAME module already installed."
    exit 0
fi

# Automatically remove liteuart module if installed.
FOUND=$(lsmod | grep liteuart)
if [ "$FOUND" != "" ] ; then
    rmmod liteuart.ko
fi

# Install litepcie module.
INS=$(insmod $NAME.ko 2>&1)
if [ "$?" != "0" ] ; then
    ERR=$(echo $INS | sed -s "s/.*$NAME.ko: //")
    case $ERR in
    'Invalid module format')
        set -e
        echo "Kernel may have changed, try to rebuild module"
        make -s clean
        make -s
        insmod $NAME.ko
        set +e
        ;;
    'No such file or directory')
        set -e
        echo "Module not compiled"
        make -s
        insmod $NAME.ko
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
    chmod 666 /dev/$NAME$i > /dev/null 2>&1
done

