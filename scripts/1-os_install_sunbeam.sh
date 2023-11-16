#!/usr/bin/env bash

CEPH_DISKS=$(./misc/ceph_disk.sh -i)
sunbeam generate-preseed | yq ' .microceph_config.*.osd_devices += "'$CEPH_DISKS'"' > /tmp/preseed.yaml

sunbeam cluster bootstrap --accept-defaults

# We removed --role control from next line as now seems to be inferred.
# sunbeam cluster bootstrap --preseed /tmp/preseed.yaml --role storage --role compute 
sunbeam cluster bootstrap --role storage --role compute 

juju switch openstack
juju integrate admin/controller.microceph cinder-ceph
echo "Watch juju status until connected"
