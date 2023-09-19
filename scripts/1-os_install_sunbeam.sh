#!/usr/bin/env bash

sunbeam cluster bootstrap --accept-defaults
sunbeam cluster bootstrap --role storage --role compute --role control
juju switch openstack
juju integrate admin/controller.microceph cinder-ceph
echo "Watch juju status until connected"
