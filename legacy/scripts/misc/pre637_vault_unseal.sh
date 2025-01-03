#!/usr/bin/env bash

SECRET=$(juju show-unit vault/0 | yq ' .vault/0.relation-info[0].application-data.vault-initialization-secret-id ')
SECRET=$(juju show-unit vault/0 |  yq ' .vault/0.relation-info[] | select(.related-endpoint=="vault-peers") | .application-data.vault-initialization-secret-id')
ROOT_TOKEN=$(juju show-secret --reveal $SECRET | yq ' .*.content.roottoken ')
UNSEAL_KEYS=( $(juju show-secret --reveal $SECRET | yq ' .*.content.unsealkeys ' | jq -r .[] ) )

for unseal_key in "${UNSEAL_KEYS[@]}"
do
   microk8s kubectl exec -n openstack vault-0 -c vault -- vault operator unseal -tls-skip-verify $unseal_key
done
