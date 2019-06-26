. ./targets.conf

TAG=${TAG:-$(date --iso-8601=seconds)}
for release in $RELEASES ; do
    for arch in $(eval echo \${QEMU_ARCHS_$release}) ; do
        echo "LTP $release $arch $TAG"
        ./test_ltp.sh "$arch" "$release" "$TAG"
    done
done
