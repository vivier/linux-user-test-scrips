. ./targets.conf
. ./helpers.sh

copy_binaries

for release in $RELEASES ; do
    for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do
        echo "$QEMU_BUILDIR $release $arch"
        if ! ./create_chroot.sh binaries/qemu-$arch $release ; then
            echo "$release $arch FAILED"
            exit 1
        fi
    done
done
