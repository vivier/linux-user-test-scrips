unset LANG
export QEMU_LOG=unimp

. ./helpers.sh

QEMU_PATH="$1"
if [ ! -x "$QEMU_PATH" ] ; then
    echo "Specify path to qemu linux-user"
    exit 1
fi

QEMU_NAME=$(basename $QEMU_PATH)
QEMU_ARCH=${QEMU_NAME##*-}

TARGET="$2"
if [ "$TARGET" = "" ] ; then
    echo "Specify distro target"
    exit 1
fi

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

case $QEMU_ARCH in
    mipsel)      UTS_MACHINE=mips ;;
    mips64el)    UTS_MACHINE=mips64 ;;
    arm)         UTS_MACHINE=armv7l ;;
    hppa)        UTS_MACHINE=parisc ;;
    sparc32plus) UTS_MACHINE=sparc64 ;;
    i386)        UTS_MACHINE=i686      ;;
    *)           UTS_MACHINE=$QEMU_ARCH ;;
esac

APT_OPT=""
DISTRO_KEYRING="debian-keyring debian-archive-keyring"
INCLUDE="iputils-ping,apt-utils,gnupg2"
case $TARGET in
    # ubuntu
    bionic)
        INCLUDE="iputils-ping,apt-utils,gnupg"
        DISTRO_KEYRING="ubuntu-keyring"
	NEED_GO="yes"
        case $ARCH in
        armhf|arm64|powerpc|ppc64el|s390x)
            REPO=http://ports.ubuntu.com/ubuntu-ports/
            ;;
	i386|amd64)
            REPO=http://ftp.ubuntu.com/ubuntu/
	    ;;
        *)
            echo "Unsupported ubuntu target $TARGET $ARCH" 1>&2
	    exit 1
	esac
        ;;
    cosmic|bionic|artful|disco|eoan)
	NEED_GO="yes"
        DISTRO_KEYRING="ubuntu-keyring" # ubuntu-extras-keyring"
        INCLUDE="iputils-ping,apt-utils,gnupg"
        case $ARCH in
        armhf|arm64|powerpc|ppc64el|s390x|i386|amd64)
            REPO=http://ftp.ubuntu.com/ubuntu/
            ;;
        *)
            echo "Unsupported ubuntu target $TARGET $ARCH" 1>&2
            exit 1
        esac
	;;
    xenial|precise|devel)
	NEED_GO="yes"
        DISTRO_KEYRING="ubuntu-keyring" # ubuntu-extras-keyring"
        INCLUDE="iputils-ping,apt-utils,gnupg"
        case $ARCH in
        armhf|arm64|powerpc|ppc64el|s390x|riscv64)
            REPO=http://ports.ubuntu.com/ubuntu-ports/
            ;;
        i386|amd64)
            REPO=http://ftp.ubuntu.com/ubuntu/
            ;;
        *)
            echo "Unsupported ubuntu target $TARGET $ARCH" 1>&2
            exit 1
        esac
	;;
    trusty)
        DISTRO_KEYRING="ubuntu-keyring ubuntu-extras-keyring"
        case $ARCH in
        armhf|arm64|powerpc|ppc64el|s390x)
            REPO=http://ports.ubuntu.com/ubuntu-ports/
            ;;
        i386|amd64)
            REPO=http://ftp.ubuntu.com/ubuntu/
            ;;
        *)
            echo "Unsupported ubuntu target $TARGET $ARCH" 1>&2
            exit 1
        esac
        ;;
    # debian
    lenny|jessie|wheezy)
        REPO=http://archive.debian.org/debian
	;;
    etch)
        REPO=http://archive.debian.org/debian
        case $ARCH in
        m68k) TARGET=etch-m68k
        esac
        ;;
    sid)
        UPDATE_OPT="--allow-unauthenticated --allow-insecure-repositories"
        UPGRADE_OPT="--allow-unauthenticated --fix-missing"
        case $ARCH in
	m68k|ppc64|sh4|riscv64|alpha|powerpc|powerpcspe|hppa)
            REPO=http://ftp.de.debian.org/debian-ports/
            ;;
	sparc64)
	    APT_CONF="APT::Sandbox::User root;"
            REPO=http://ftp.de.debian.org/debian-ports/
            ;;
        *)
	    REPO=http://ftp.de.debian.org/debian
	    NEED_GO="yes"
	    ;;
        esac
        ;;
    stretch)
        REPO=http://ftp.de.debian.org/debian
        ;;
    buster)
        NEED_GO=yes
        REPO=http://ftp.de.debian.org/debian
        ;;
    *)  echo "Unknown distro target $TARGET"
        exit 1
        ;;
esac

echo "REPO=$REPO"

CHROOT=chroot/$ARCH/$TARGET

if [ ! -d $CHROOT ] ; then
    mkdir -p $CHROOT
    debootstrap --include="$INCLUDE" \
                --arch=$ARCH --foreign --variant=minbase --no-check-gpg \
                $TARGET $CHROOT $REPO && \
    cp "$QEMU_PATH" $CHROOT/ && \
    isolate $CHROOT ./debootstrap/debootstrap --second-stage || exit

    if [ "$APT_CONF" != "" ] ; then
        echo "$APT_CONF" > $CHROOT/etc/apt/apt.conf
    fi

    cat > $CHROOT/etc/apt/sources.list <<EOF
deb $REPO $TARGET main
EOF

    if [ $? -ne 0 ] ; then
        exit
    fi
    isolate $CHROOT apt-get clean
    (mkdir -p rootfs/$ARCH/$TARGET && cd $CHROOT && tar Jcf $OLDPWD/rootfs/$ARCH/$TARGET/rootfs.tar.xz .)
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

TARGET_MACHINE=$(isolate $CHROOT uname -m)
if [ "$TARGET_MACHINE" != "$UTS_MACHINE" ] ; then
    echo "UTS machine mismatch $TARGET_MACHINE and $UTS_MACHINE" 1>&2
    exit 1
fi


cat archive_2020.key | isolate $CHROOT apt-key add -

if isolate $CHROOT which ip ; then
	isolate $CHROOT ip l || exit
	isolate $CHROOT ip a || exit
	isolate $CHROOT ip r || exit
fi
isolate $CHROOT uname -a &&
isolate $CHROOT date &&
isolate $CHROOT ls -l /qemu-$QEMU_ARCH && 
isolate $CHROOT apt-get update $UPDATE_OPT --yes &&
isolate $CHROOT apt-get upgrade $UPGRADE_OPT --yes &&
isolate $CHROOT apt-get install --yes --allow-unauthenticated $DISTRO_KEYRING &&
isolate $CHROOT apt-get install --yes --allow-unauthenticated gcc libc6-dev &&
isolate $CHROOT apt-key update &&
isolate $CHROOT gcc /tmp/hello.c -o /tmp/hello &&
isolate $CHROOT /tmp/hello | grep "Hello World!" || exit

if [ "$NEED_GO" = "yes" ] ; then
    isolate $CHROOT apt-get install --yes --allow-unauthenticated golang || exit

    if [ -x $CHROOT/usr/bin/go ] ; then
	    cat > $CHROOT/tmp/hello.go <<EOF
package main

import "fmt"

func main() {
        fmt.Println("Hello Google!")
}
EOF
    fi
    isolate $CHROOT go run /tmp/hello.go
fi
