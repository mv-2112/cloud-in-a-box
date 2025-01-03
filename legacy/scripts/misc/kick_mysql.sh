#!/usr/bin/env bash

kubectl get pods -n openstack --no-headers=true | awk '/mysql-0/{print $1}' | xargs  kubectl delete -n openstack pod
