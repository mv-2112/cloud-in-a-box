#!/usr/bin/env bash

for each in $(grep -A 5 Unseal ./vault_keys | tail +2); do sunbeam vault unseal $each; done


sudo snap set openstack-hypervisor logging.debug=true && sudo snap set openstack-hypervisor logging.debug=false
