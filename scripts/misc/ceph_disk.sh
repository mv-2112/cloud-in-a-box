#!/usr/bin/env bash

ROOT_PARTITION_NAME=$(mount | grep ' on / ' | cut -d' ' -f1 | cut -d'/' -f3)
ROOT_DISK=$(basename `readlink -f "/sys/class/block/${ROOT_PARTITION_NAME}/.."`)
ROOT_DISK_WWN=$(cat /sys/class/block/${ROOT_DISK}/device/wwid)
ROOT_DISK_WWNTYPE=$(echo ${ROOT_DISK_WWN} | cut -d"." -f1)
ROOT_DISK_WWNUID=$(echo ${ROOT_DISK_WWN} | cut -d"." -f2)
AVAILABLE_DISKS=$(ls  /dev/disk/by-id/wwn* | grep -v part | grep -v ${ROOT_DISK_WWNUID} | tr "\n" "," | sed 's/,$//')

# echo "Identified root partition as [${ROOT_PARTITION_NAME}]"
# echo "Identified root disk device as [${ROOT_DISK}]"
# echo "WWN for [${ROOT_DISK}] is [${ROOT_DISK_WWNTYPE}].[${ROOT_DISK_WWNUID}]"
# echo "Excluding $ROOT_DISK we found [${AVAILABLE_DISKS}] potentially usable for Ceph"

usage() {                                 
  echo "Usage: $0 [ -z <disk string> ] [ -i ]" 1>&2 
}

exit_abnormal() {
  usage
  exit 1
}

msg_out=$AVAILABLE_DISKS

while getopts ":z:yih" options; do
  case "${options}" in
    h)
      usage
      ;;
    z)
      ZAP_DISKS=${OPTARG}
      ZAP_DISKS=$(echo $ZAP_DISKS | tr ',' ' ')
      for each_disk in $(echo $ZAP_DISKS)
      do 
        echo "Zapping $each_disk"
        wipefs -af $each_disk
      done
      msg_out="Cleared disks $ZAP_DISKS."
      ;;
    y)
	    msg_out=$(echo '"'$AVAILABLE_DISKS'"' | sed 's/,/","/g')
      ;;
    i)
      msg_out=${AVAILABLE_DISKS}
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

echo $msg_out
