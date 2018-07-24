unset LANG

. ./helpers.sh

umount_cleanup

TAR=ltp-full-20180515

ARCH=$1
RELEASE=$2
TAG=$3
if [ "$TAG" = "" ] ; then
    TAG=$(date --iso-8601=seconds)
fi

CHROOT=chroot/$ARCH/$RELEASE
ARCHIVE=archive/$ARCH/$TAG

rm -f archive/$ARCH/previous
mv archive/$ARCH/latest archive/$ARCH/previous
mkdir -p $ARCHIVE

$CHROOT/qemu-* -version > $ARCHIVE/VERSION
cat $CHROOT/etc/debian_version > $ARCHIVE/RELEASE
RELEASE=$(cat $ARCHIVE/RELEASE)

APT_OPT=--allow-insecure-repositories
if [ "$RELEASE" = "8.10" -o "$RELEASE" = "5.0.10" ]; then
    APT_OPT=""
fi

chroot $CHROOT apt-get --allow-unauthenticated $APT_OPT -y update
chroot $CHROOT apt-get -y --allow-unauthenticated install gcc xz-utils make sudo iproute2 procps

if [ ! -e $CHROOT/root/$TAR ] ; then
    ( cp $TAR.tar.xz $CHROOT/root  && \
      cd $CHROOT/root && tar Jxvf $TAR.tar.xz )
fi

if [ ! -d $CHROOT/opt/ltp ] ; then

    rm -f $CHROOT/opt/ltp
    chroot $CHROOT 2>&1 <<EOF
cd /root/$TAR && \
./configure && \
make -j $(getconf _NPROCESSORS_ONLN) && \
make install
EOF

    if [ $? -ne 0 ] ; then
        exit
    fi
fi 2>&1 | tee $ARCHIVE/build.log

cp skipfile $CHROOT/opt/ltp

if [ "$ARCH" = "mipsel" ] ; then
cat >> $CHROOT/opt/ltp/skipfile <<EOF
fstat05
EOF
elif [ "$ARCH" = "mips64el" ] ; then
cat >> $CHROOT/opt/ltp/skipfile <<EOF
fcntl14
fcntl14_64
EOF
elif [ "$ARCH" = "aarch64" ] ; then
cat >> $CHROOT/opt/ltp/skipfile <<EOF
futex_wait03
msgctl10
EOF
elif [ "$ARCH" = "armhf" ] ; then
cat >> $CHROOT/opt/ltp/skipfile <<EOF
creat07
futex_wait03
msgctl10
EOF
fi

mount /proc $CHROOT/proc -o bind && \
mount /dev $CHROOT/dev -o bind && \
chroot $CHROOT <<EOF
cd /opt/ltp &&
rm -f output/* results/* &&
time ./runltp -f syscalls -S ./skipfile -g ltp-$ARCH-$TAG.html -o ltp-$ARCH-$TAG.log
EOF
umount_cleanup
cp -pr $CHROOT/opt/ltp/results $CHROOT/opt/ltp/output $ARCHIVE
sed -i "s?/opt/ltp?$SARCHIVE?g" $ARCHIVE/output/ltp-$ARCH-$TAG.html
ln -s $TAG archive/$ARCH/latest
