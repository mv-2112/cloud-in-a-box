sudo snap install openstack --channel 2024.1/edge

sunbeam prepare-node-script --bootstrap | bash -x && newgrp snap_daemon

sunbeam cluster bootstrap --role compute,control,storage --topology single
sunbeam configure --openrc demo-openrc
sunbeam openrc > admin_openrc
source ./admin_openrc 
echo $OS_PASSWORD
echo $OS_USER_DOMAIN_NAME
sunbeam enable loadbalancer
sunbeam enable vault

sunbeam vault init  5 3 > vault_keys
for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done
sunbeam vault authorize-charm $(grep Root ./vault_keys | cut -d: -f2)
sunbeam enable caas
