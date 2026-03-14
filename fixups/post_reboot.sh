#!/usr/bin/env bash

sunbeam utils juju-login

sudo k8s kubectl -n openstack rollout restart statefulset horizon
sudo k8s kubectl -n openstack rollout status statefulset horizon

#sudo k8s kubectl -n openstack rollout restart statefulset ovn-central
#sudo k8s kubectl -n openstack rollout status statefulset ovn-central
juju config ovn-central ovsdb-server-election-timer=6



sudo snap restart openstack.clusterd
sudo snap set openstack-hypervisor logging.debug=true && sudo snap set openstack-hypervisor logging.debug=false

for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done





# juju show-unit ovn-central/0 --endpoint certificates --format yaml |  yq -r '."ovn-central/0"."relation-info"[0]."application-data".certificates' | jq -r '.[0].certificate_signing_request' | openssl req -text | egrep "Address|Subject"

