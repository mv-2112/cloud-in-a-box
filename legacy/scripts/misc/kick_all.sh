#!/usr/bin/env bash

sudo kubectl get pods -n openstack --no-headers=true | awk '{ print $1 }' | xargs  sudo kubectl delete -n openstack pod
