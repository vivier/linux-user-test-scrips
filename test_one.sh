unset LANG
TAR=glibc-2.27
cp $TAR.tar.xz $1 && \
chroot $1 apt -y --allow-unauthenticated install gcc xz-utils make gawk bison libgetopt-simple-perl && \
chroot $1 <<EOF
test -d $TAR || tar Jxvf $TAR.tar.xz
cd $TAR && rm -fr build && mkdir build && cd build && ../configure --prefix=/opt/libc && make -j $(getconf _NPROCESSORS_ONLN)
EOF
