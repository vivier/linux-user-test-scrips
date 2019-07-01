. ./targets.conf

for release in $RELEASES ; do
    for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do

	#echo -n "qemu-$arch "
	case $arch in
	ppc)         arch=powerpc    ;;
	ppc64le)     arch=ppc64el    ;;
	sparc32plus) arch=sparc      ;;
	arm)         arch=armhf      ;;
	armeb)       arch=armel      ;;
	aarch64)     arch=arm64      ;;
	x86_64)      arch=amd64      ;;
	esac

        if [ "$arch" = "m68k" -a "$release" = "etch" ] ; then
                release="etch-m68k"
        fi

	echo "$arch/$release"
    done
done
