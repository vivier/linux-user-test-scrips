. ./targets.conf

RELEASES="stretch disco"

for release in $RELEASES ; do
    for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do
		if ! ./build_qemu.sh $arch $release ; then
			echo "$arch $release FAILED"
			exit 1
		fi
	done
done
