unset LANG
export QEMU_LOG=unimp

. ./helpers.sh

QEMU_PATH="$1"
if [ ! -x "$QEMU_PATH" ] ; then
    echo "Specify path to qemu linux-user"
    exit 1
fi

if ! file "$QEMU_PATH" | grep -q "statically linked" ; then
    echo "$QEMU_PATH needs to be statically linked"
    exit 1
fi

QEMU_NAME=$(basename $QEMU_PATH)
QEMU_ARCH=${QEMU_NAME##*-}

TARGET="${2#fc}"
if [ "$TARGET" = "" ] ; then
    echo "Specify distro target"
    exit 1
fi

if [ "$ARCH" == "" ]; then
    case $QEMU_ARCH in
        arm)         ARCH=armhfp     ;;
        *)           ARCH=$QEMU_ARCH ;;
    esac
fi

case $QEMU_ARCH in
    mipsel)      UTS_MACHINE=mips ;;
    mips64el)    UTS_MACHINE=mips64 ;;
    arm)         UTS_MACHINE=armv7l ;;
    hppa)        UTS_MACHINE=parisc ;;
    sparc32plus) UTS_MACHINE=sparc ;;
    i386)        UTS_MACHINE=i686      ;;
    *)           UTS_MACHINE=$QEMU_ARCH ;;
esac

BASEURL="http://download-ib01.fedoraproject.org/pub/fedora-secondary/releases/${TARGET}"
REPO="$BASEURL/Server/os"
echo "REPO=$REPO"

NAME=Fedora-Container-Base-$TARGET-1.2.$ARCH.tar.xz
case $QEMU_ARCH in
    s390x)	NAME=Fedora-Container-Minimal-Base-$TARGET-1.2.$ARCH.tar.xz ;;
esac

CHROOT=chroot/$ARCH/${TARGET}

if [ ! -d $CHROOT ] ; then
    mkdir -p $CHROOT

    TOP=$PWD
    TEMP=$(mktemp -d)
    cd $TEMP && \
    curl -o container.tar.xz  $BASEURL/Container/$ARCH/images/$NAME && \
    tar Jxvf container.tar.xz */layer.tar && \
    (cd $TOP/$CHROOT && tar xf $TEMP/*/layer.tar) && rm -fr "$TEMP"

    if [ $? -ne 0 ] ; then
        exit
    fi
    cd $TOP
    (mkdir -p rootfs/$ARCH/${TARGET} && cd $CHROOT && tar Jcf $TOP/rootfs/$ARCH/${TARGET}/rootfs.tar.xz .)
    cp "$QEMU_PATH" $CHROOT/ || exit 1
else
    echo "$CHROOT exists, updating qemu and skipping"
    cp "$QEMU_PATH" $CHROOT/ || exit 1
fi
$CHROOT/$QEMU_NAME -version

cat > $CHROOT/tmp/hello.c <<EOF
#include <stdio.h>
int main(void)
{
    printf("Hello World!\n");
    return 0;
}
EOF

TARGET_MACHINE=$(chroot $CHROOT uname -m)
if [ "$TARGET_MACHINE" != "$UTS_MACHINE" ] ; then
    echo "UTS machine mismatch $TARGET_MACHINE and $UTS_MACHINE" 1>&2
    exit 1
fi

isolate $CHROOT dnf update -y &&
isolate $CHROOT uname -a &&
isolate $CHROOT date &&
isolate $CHROOT ls -l /qemu-$QEMU_ARCH && 
isolate $CHROOT dnf install -y gcc
isolate $CHROOT gcc /tmp/hello.c -o /tmp/hello &&
isolate $CHROOT /tmp/hello | grep "Hello World!"
