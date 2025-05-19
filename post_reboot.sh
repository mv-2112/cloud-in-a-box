#!/usr/bin/env bash

sunbeam utils juju-login

sudo kubectl delete pod horizon-0 -n openstack &
sudo snap restart openstack.clusterd
sudo snap set openstack-hypervisor logging.debug=true && sudo snap set openstack-hypervisor logging.debug=false

for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done
