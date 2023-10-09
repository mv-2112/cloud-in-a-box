#!/usr/bin/env bash

sunbeam cluster bootstrap --accept-defaults

# We removed --role control from next line as now seems to be inferred.
sunbeam cluster bootstrap --role storage --role compute 

juju switch openstack
juju integrate admin/controller.microceph cinder-ceph
echo "Watch juju status until connected"
