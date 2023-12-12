#!/usr/bin/env bash

SRV=$1

kubectl get pods -n openstack --no-headers=true | awk '/'$SRV'/{print $1}'| xargs  kubectl delete -n openstack pod
