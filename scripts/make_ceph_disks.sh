#!/usr/bin/env bash

fqdn="example.com."
num_disks=3
disk_size=100
path=/media/targets
#IP_ADDRESS=$(ip -4 -o addr show eno1 | sed -r 's:.* (([0-9]{1,3}\.){3}[0-9]{1,3})/.*:\1:')
MY_IQN="iqn.$(date +'%Y-%m').$(echo $fqdn | tac -s'.' | xargs | sed 's/\.$//'):$(hostname).target1"


check_pks() {
  for each_pkg in tgt open-iscsi
  do
   if [[ "$(dpkg-query -W --showformat='${Status}\n' $each_pkg)" == "install ok installed" ]]; then
     echo "$each_pkg installed"
   else
     echo "$each_pkg not installed"
     sudo apt install $each_pkg -y
   fi
  done
}

usage() {                                 
  echo "Usage: $0 [ -p <path> ] [ -n <number> ] [ -s <size> ]" 1>&2 
  echo -e "\t -p the path at which to create the devices (default: $path)" 1>&2 
  echo -e "\t -n the number of devices to create (default: $num_disks)" 1>&2 
  echo -e "\t -s the size of the devices to create (default: $disk_size)" 1>&2 
}

exit_abnormal() {
  usage
  exit 1
}


while getopts "p:s:n:h" options; do
  case "${options}" in
    h)
      usage
      exit 0
      ;;
    p)
      path=${OPTARG}
      ;;
    s)
      disk_size=${OPTARG}
      ;;
    n)
      num_disks=${OPTARG}
      ;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;
  esac
done

check_pkgs()

if [[ ! -d $path ]];then
  sudo mkdir $path
fi


# Create our iscsi conf as we create the backing devices...
sudo tgtadm -C 0 --lld iscsi --op new --mode target --tid 1 -T $MY_IQN
for each_disk in $(seq 1 $num_disks)
do
  echo "Creating disk $each_disk/$num_disks at $path - size $disk_size"
  sudo fallocate -l ${disk_size}G ${path}/ceph_disk${each_disk}.img
  sudo tgtadm --op new --mode logicalunit --tid 1 --lun $each_disk --backing-store ${path}/ceph_disk${each_disk}.img
done
sudo tgt-admin --dump > /etc/tgt/$(hostname)-openstack-ceph-disks.conf
sudo tgt-admin --update tid=1

#sudo iscsiadm -m iface -I eno1 --op=new
#sudo iscsiadm -m iface -I eno1 --op=update -n iface.hwaddress -v  48:0f:cf:54:a6:3d
#sudo iscsiadm -m iface -I eno1 --op=update -n iface.ipaddress -v ${IP_ADDRESS}

sudo iscsiadm -m discovery -t sendtargets -p ${IP_ADDRESS}
sudo iscsiadm -m discovery -t sendtargets -p ${IP_ADDRESS}
sudo iscsiadm -m node --login -p ${IP_ADDRESS}
sudo iscsiadm -m node -p ${IP_ADDRESS} -o update -n node.startup -v automatic 


