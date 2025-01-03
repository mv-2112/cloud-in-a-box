#!/bin/bash

for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql$ )
do
    kubectl patch statefulset $each_mysql -n openstack -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"charm"},{"name":"mysql"}],"containers":[{"livenessProbe":{"failureThreshold":10,"initialDelaySeconds":300,"timeoutSeconds":10},"name":"charm","readinessProbe":{"failureThreshold":10, "initialDelaySeconds":300,"timeoutSeconds":10},"startupProbe":{"failureThreshold":10,"initialDelaySeconds":300,"timeoutSeconds":10}},{"livenessProbe":{"failureThreshold":10, "initialDelaySeconds":300,"timeoutSeconds":10},"name":"mysql","readinessProbe":{"failureThreshold":10, "initialDelaySeconds":300,"timeoutSeconds":10}}]}}}}'
done