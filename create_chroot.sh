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

APT_OPT=""
case $TARGET in
    lenny) REPO=http://archive.debian.org/debian ;;
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

if [ -d $CHROOT ] ; then
    cp "$QEMU_PATH" $CHROOT/ || exit 1
    echo "$CHROOT exists, updating qemu and skipping"
    exit 0
fi
 
mkdir -p $CHROOT
debootstrap --arch=$ARCH --foreign --variant=minbase --no-check-gpg $TARGET $CHROOT $REPO && \
cp "$QEMU_PATH" $CHROOT/ && \
chroot $CHROOT ./debootstrap/debootstrap --second-stage || exit

cat > $CHROOT/etc/apt/sources.list <<EOF
deb $REPO $TARGET main
EOF

if [ $? -ne 0 ] ; then
    exit
fi

chroot $CHROOT apt-get update $UPDATE_OPT --yes && \
chroot $CHROOT apt-get upgrade $UPGRADE_OPT --yes
