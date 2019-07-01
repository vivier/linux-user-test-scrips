unset LANG LC_PAPER LC_MONETARY LC_NUMERIC LC_MEASUREMENT LC_TIME LANG

. ./helpers.sh

QEMU_ARCH="$1"
RELEASE="$2"

if [ "$ARCH" == "" ]; then
    case $QEMU_ARCH in
        ppc)         ARCH=powerpc    ;;
        ppc64le)     ARCH=ppc64el    ;;
        sparc32plus) ARCH=sparc      ;;
        arm)         ARCH=armhf      ;;
        armeb)       ARCH=armel      ;;
        aarch64)     ARCH=arm64      ;;
        x86_64)      ARCH=amd64      ;;
        *)           ARCH=$QEMU_ARCH ;;
    esac
fi

if [ "$ARCH" = "m68k" -a "$RELEASE" = "etch" ] ; then
    RELEASE="etch-m68k"
fi

echo "ARCH=$ARCH"
echo "RELEASE=$RELEASE"

PACKAGES="git python3 make pkg-config libglib2.0-dev"
CHROOT=chroot/$ARCH/$RELEASE
J=$(($(getconf _NPROCESSORS_ONLN) * 2 + 1))

isolate $CHROOT <<EOF
mount proc /proc -t proc
mount devpts /dev/pts -t devpts
apt-get install --yes --allow-unauthenticated $PACKAGES
EOF

(cd $CHROOT/root && rm -fr Objects qemu && mkdir Objects && \
 git clone -b linux-user-for-4.1 /home/lvivier/Projects/qemu &&
 cd qemu && scripts/git-submodule.sh update ui/keycodemapdb tests/fp/berkeley-testfloat-3 tests/fp/berkeley-softfloat-3 capstone) &&
isolate $CHROOT <<EOF
cd /root/qemu && \
cd /root/Objects && \
../qemu/configure --disable-slirp --disable-fdt --disable-system --disable-tools --enable-user && \
make -j $J
EOF
