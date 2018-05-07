for dir in $(ls -d chroot/*/*) ; do
    target=${dir##chroot/}
    arch=${target%%/*}
    release=${target##*/}
    ./test_ltp.sh $arch $release
done
