#!/usr/bin/env bash

# CEPH_DISKS=$(./misc/ceph_disk.sh -i)
# sunbeam generate-preseed | yq ' .microceph_config.*.osd_devices += "'$CEPH_DISKS'"' > /tmp/preseed.yaml

# Post 385/386 we've moved to manifests
# sunbeam generate-preseed | yq ".microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" > ../sunbeam-preseed.yaml

echo "Generating empty manifext file"
sunbeam manifest generate -f ../sunbeam-manifest.yaml
echo "Inserting disks for Ceph config"
yq -i ".deployment.microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" ../sunbeam-manifest.yaml
yq -i ".juju.charms.mysql-k8s.config.profile-limit-memory=4096 " ../sunbeam-manifest.yaml

# Lets go all in now on the single bootstrap now its faster
# sunbeam cluster bootstrap --accept-defaults

# We removed --role control from next line as now seems to be inferred.
# Post 385/386 we've moved to manifests
# sunbeam cluster bootstrap --preseed ../sunbeam-preseed.yaml --role storage --role compute --role control
# sunbeam cluster bootstrap --role storage --role compute 
sunbeam cluster bootstrap --manifest ../sunbeam-manifest.yaml --role storage --role compute --role control

juju switch openstack
juju integrate admin/controller.microceph cinder-ceph
echo "Watch juju status until connected"
