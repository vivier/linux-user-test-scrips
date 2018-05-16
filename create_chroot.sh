unset LANG

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

TARGET="$2"
if [ "$TARGET" = "" ] ; then
    echo "Specify distro target"
    exit 1
fi

case $QEMU_ARCH in
    ppc)         ARCH=powerpc    ;;
    ppc64le)     ARCH=ppc64el    ;;
    sparc32plus) ARCH=sparc      ;;
    arm)         ARCH=armhf      ;;
    armeb)       ARCH=armel      ;;
    aarch64)     ARCH=arm64      ;;
    *)           ARCH=$QEMU_ARCH ;;
esac

case $QEMU_ARCH in
    mipsel)      UTS_MACHINE=mips ;;
    mips64el)    UTS_MACHINE=mips64 ;;
    arm)         UTS_MACHINE=armv7l ;;
    hppa)        UTS_MACHINE=parisc ;;
    *)           UTS_MACHINE=$QEMU_ARCH ;;
esac

APT_OPT=""
case $TARGET in
    lenny) REPO=http://archive.debian.org/debian ;;
    etch)
        REPO=http://archive.debian.org/debian
        case $QEMU_ARCH in
        m68k) TARGET=etch-m68k
        esac
        ;;
    sid)
        UPDATE_OPT="--allow-unauthenticated --allow-insecure-repositories"
        UPGRADE_OPT="--allow-unauthenticated"
        case $QEMU_ARCH in
        m68k|ppc64|sh4|sparc64|riscv64|alpha)
            REPO=http://cdn-fastly.deb.debian.org/debian-ports/
            ;;
        *)  REPO=http://ftp.fr.debian.org/debian  ;;
        esac
        ;;
    *)     REPO=http://ftp.fr.debian.org/debian  ;;
esac

CHROOT=chroot/$ARCH/$TARGET

if [ ! -d $CHROOT ] ; then
    mkdir -p $CHROOT
    debootstrap --arch=$ARCH --foreign --variant=minbase --no-check-gpg \
                $TARGET $CHROOT $REPO && \
    cp "$QEMU_PATH" $CHROOT/ && \
    chroot $CHROOT ./debootstrap/debootstrap --second-stage || exit

    cat > $CHROOT/etc/apt/sources.list <<EOF
deb $REPO $TARGET main
EOF

    if [ $? -ne 0 ] ; then
        exit
    fi
else
    echo "$CHROOT exists, updating qemu and skipping"
    cp "$QEMU_PATH" $CHROOT/ || exit 1
fi

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

chroot $CHROOT ip a
chroot $CHROOT uname -a &&
chroot $CHROOT date &&
chroot $CHROOT ls -l /qemu-$QEMU_ARCH && 
chroot $CHROOT apt-get update $UPDATE_OPT --yes &&
chroot $CHROOT apt-get upgrade $UPGRADE_OPT --yes &&
chroot $CHROOT apt-get install --yes --allow-unauthenticated debian-keyring debian-archive-keyring gcc libc6-dev &&
chroot $CHROOT apt-key update &&
chroot $CHROOT gcc /tmp/hello.c -o /tmp/hello &&
chroot $CHROOT /tmp/hello | grep "Hello World!"
