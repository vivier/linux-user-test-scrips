function copy_binaries
{
    mkdir -p binaries
    for release in $RELEASES ; do
        for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do
            echo $arch
        done
    done | sort -u | while read arch ; do
        cp $QEMU_BUILDIR/$arch-linux-user/qemu-$arch binaries
    done
}

function umount_cleanup
{
    grep chroot /etc/mtab|cut -d' ' -f 2,2 | while read mountpoint; do
        umount $mountpoint
    done
}
