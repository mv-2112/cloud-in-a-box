sudo snap install openstack --channel 2025.1/edge

sunbeam prepare-node-script --bootstrap | bash -x && newgrp snap_daemon

sunbeam cluster bootstrap --role compute,control,storage --accept-defaults
sunbeam configure --openrc demo-openrc
sunbeam openrc > admin_openrc
source ./admin_openrc 
echo $OS_PASSWORD
echo $OS_USER_DOMAIN_NAME

# Fix missing glyphs etc
sudo k8s kubectl -n openstack patch statefulset horizon --patch-file ./fixups/horizon-static-url-patch.yaml
sudo k8s kubectl -n openstack rollout restart statefulset horizon
sudo k8s kubectl -n openstack rollout status statefulset horizon


sunbeam enable loadbalancer
sunbeam enable vault

sunbeam vault init  5 3 > vault_keys
for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done
sunbeam vault authorize-charm $(grep Root ./vault_keys | cut -d: -f2)
sunbeam enable caas


# Fix magnum kubeconfig
sudo cat /root/.kube/config | yq ".clusters[].cluster.server = \"https://$(hostname -i):6443\"" > ./openstack_config

juju switch mz640/openstack
juju add-secret secret-kubeconfig kubeconfig#file=./openstack_kubeconfig
juju grant-secret secret-kubeconfig magnum
juju config magnum kubeconfig=secret:$(juju show-secret secret-kubeconfig --format=yaml | yq "keys[]")

if [[ ! -f /usr/local/bin/clusterctl ]]; then
  curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.10.5/clusterctl-linux-amd64 -o clusterctl
  sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
fi

# sudo k8s config > kubeconfig
# KUBECONFIG=kubeconfig clusterctl get kubeconfig --namespace magnum-<PROJECT_ID> <CLUSTER_STACK_ID> > config-dir/config

