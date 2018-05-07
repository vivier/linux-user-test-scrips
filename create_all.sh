QEMU_BUILDIR=/home/laurent/Projects/qemu/build/linux-user

RELEASES="stretch jessie wheezy lenny sid"

QEMU_ARCHS_stretch="s390x ppc64le mipsel mips64el mips arm aarch64"
QEMU_ARCHS_jessie="ppc"
#QEMU_ARCHS_wheezy="sparc32plus"
QEMU_ARCHS_lenny="hppa"
#QEMU_ARCHS_sid="m68k ppc64 sh4 sparc64 riscv64" sparc64 crashes
QEMU_ARCHS_sid="m68k ppc64 sh4 alpha"


for release in $RELEASES ; do
    for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do
        echo "$QEMU_BUILDIR $release $arch"
        if ! ./create_chroot.sh $QEMU_BUILDIR/$arch-linux-user/qemu-$arch $release ; then
            echo "$release $arch FAILED"
            exit 1
        fi
    done
done
