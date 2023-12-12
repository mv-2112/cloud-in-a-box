#!/usr/bin/env bash

kubectl get pods -n openstack --no-headers=true | awk '{ print $1 }' | xargs  kubectl delete -n openstack pod
