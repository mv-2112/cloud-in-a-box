#!/usr/bin/env bash

# Remove Openstack itself
sudo snap remove --purge openstack
sudo snap remove --purge openstack-hypervisor


# Tidy up Ceph
for each_disk in sda sdb sdc sdd
do
  microceph.ceph-bluestore-tool zap-device --dev /dev/$each_disk
  # sudo dd if=/dev/zero of=/dev/$each_disk bs=1M count=100 status=progress
  # wipefs -af /dev/$each_disk
done
sudo snap remove --purge microceph


# Remove the bootstrap stuff
sudo snap remove --purge k8s 
sudo snap remove --purge cinder-volume
sudo snap remove --purge kubectl
sudo snap remove --purge epa-orchestrator
sudo snap remove --purge juju 


# Remove misc files
sudo /usr/sbin/remove-juju-services
sudo rm -rf /var/lib/juju
rm -rf ~/.local/share/juju
rm -rf ~/.local/share/openstack
rm -rf ~/snap/openstack
rm -rf ~/snap/openstack-hypervisor
rm -rf ~/snap/microstack/
rm -rf ~/snap/juju/
rm -rf ~/snap/k8s/
rm -rf /run/containerd


# Remove LXD
for each in $(lxc list -c n -f csv); do lxc stop $each; lxc delete $each; done
sudo snap remove --purge lxd
