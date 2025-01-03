sudo snap remove --purge microk8s 
sudo snap remove --purge juju 
sudo snap remove --purge openstack
sudo snap remove --purge openstack-hypervisor
sudo snap remove --purge microceph
sudo /usr/sbin/remove-juju-services
sudo rm -rf /var/lib/juju
rm ../auth/*
rm -rf ~/.local/share/juju
rm -rf ~/.local/share/openstack
rm -rf ~/snap/openstack
rm -rf ~/snap/openstack-hypervisor
rm -rf ~/snap/microstack/
rm -rf ~/snap/juju/
rm -rf ~/snap/microk8s/

rm ../auth/*

sudo ./misc/ceph_disk.sh -z $(./misc/ceph_disk.sh -i)
