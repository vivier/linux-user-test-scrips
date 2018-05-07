wget http://xillybus.com/downloads/xillybus.img.gz
gzip -d xillybus.img.gz
modprobe loop max_part=7
losetup -f xillybus.img
mount /dev/loop0p2 mnt
mkdir mnt
cd mnt
tar Jcvf ../rootfs-microblazeel.tar.xz .
umount mnt
losetup -d /dev/loop0
rmdir mnt
mkdir -p microblazeel/xillybus &&  cd microblazeel/xillybus
tar Jxvf ../../rootfs-microblazeel.tar.xz
cp /home/laurent/Projects/qemu/build/linux-user/microblazeel-linux-user/qemu-microblazeel .
cd ../..

