sudo snap remove --purge juju 
sudo snap remove --purge openstack
sudo snap remove --purge openstack-hypervisor
sudo snap remove --purge microceph
sudo snap remove --purge k8s 
sudo snap remove --purge cinder-volume
sudo snap remove --purge lxd
sudo snap remove --purge kubectl
sudo snap remove --purge epa-orchestrator


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


for each in $(lxc list -c n -f csv); do lxc stop $each; lxc delete $each; done

sudo wipefs -af /dev/sda
sudo wipefs -af /dev/sdb
sudo wipefs -af /dev/sdc
sudo wipefs -af /dev/sdd
