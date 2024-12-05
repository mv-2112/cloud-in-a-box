#!/usr/bin/env bash


# Source https://docs.openstack.org/magnum/latest/user/index.html
# Source https://docs.openstack.org/magnum/latest/install/launch-instance.html
# Source https://builds.coreos.fedoraproject.org/browser?stream=stable&arch=x86_64

distro_tag="fedora-coreos" # i.e as opposed to just coreos


get_coreos() {
    FCOS_VERSION=$1
    wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${FCOS_VERSION}/x86_64/fedora-coreos-${FCOS_VERSION}-openstack.x86_64.qcow2.xz

    unxz fedora-coreos-${FCOS_VERSION}-openstack.x86_64.qcow2.xz

    openstack image create \
                      --disk-format=qcow2 \
                      --container-format=bare \
                      --file=fedora-coreos-${FCOS_VERSION}-openstack.x86_64.qcow2 \
                      --property os_distro=$distro_tag \
                      fedora-coreos-${FCOS_VERSION}
}


for each in "35.20220116.3.0" "38.20230806.3.0" "38.20231027.3.2" "40.20241019.3.0 "
do
    echo "Getting CoreOS $each"
    get_coreos $each
done
