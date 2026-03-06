#!/usr/bin/env bash

for each_disk in sda sdb sdc sdd
do
  echo "Zapping $each_disk"
  sudo microceph.ceph-bluestore-tool zap-device --dev /dev/$each_disk --yes-i-really-really-mean-it
  echo "Wiping $each_disk"
  sudo wipefs -af /dev/$each_disk
  sudo sgdisk --zap-all /dev/$each_disk
  sudo sgdisk --clear /dev/$each_disk
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=9 seek=0
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=1 seek=128
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=1 seek=2048
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=2097152
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=20971520
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=209715200
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=4 seek=2097152000
  DISKSIZE=$(sudo blockdev --getsize64 /dev/$each_disk)
  LASTBLOCK=$(( $DISKSIZE / 512 ))
  sudo dd conv=fsync if=/dev/zero of=/dev/$each_disk bs=512 count=2 seek=$(($LASTBLOCK - 2))
done

