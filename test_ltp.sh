unset LANG

TAG=$(date --iso-8601=seconds)
TAR=ltp-full-20180118

ARCH=$1
RELEASE=$2
CHROOT=chroot/$ARCH/$RELEASE
ARCHIVE=archive/$ARCH/$TAG

rm -f archive/$ARCH/previous
mv archive/$ARCH/latest archive/$ARCH/previous
mkdir -p $ARCHIVE

cp $TAR.tar.xz $CHROOT/root && \
chroot $CHROOT apt --allow-unauthenticated --allow-insecure-repositories -y update &&
chroot $CHROOT apt -y --allow-unauthenticated install gcc xz-utils make sudo iproute2 procps && \
if [ ! -d $CHROOT/opt/ltp ] ; then

    chroot $CHROOT 2>&1 <<EOF
cd /root && \
tar Jxvf $TAR.tar.xz && \
cd $TAR && \
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
sudo umount $CHROOT/proc
sudo umount $CHROOT/dev
$CHROOT/qemu-* -version > $ARCHIVE/VERSION
cat $CHROOT/etc/debian_version > $ARCHIVE/RELEASE
cp -pr $CHROOT/opt/ltp/results $CHROOT/opt/ltp/output $ARCHIVE
sed -i "s?/opt/ltp?$SARCHIVE?g" $ARCHIVE/output/ltp-$ARCH-$TAG.html
ln -s $TAG archive/$ARCH/latest

