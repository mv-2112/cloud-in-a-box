#!/usr/bin/env bash
# After a host reboot: unseal Vault and nudge the services that don't recover
# on their own. Run from anywhere; reads ../vault_keys (written by install.sh).
set -uo pipefail
KEYS="$(cd "$(dirname "$0")/.." && pwd)/vault_keys"

sunbeam utils juju-login

sudo k8s kubectl -n openstack rollout restart statefulset horizon
sudo k8s kubectl -n openstack rollout status statefulset horizon

juju config ovn-central ovsdb-server-election-timer=6

sudo snap restart openstack.clusterd
sudo snap set openstack-hypervisor logging.debug=true && sudo snap set openstack-hypervisor logging.debug=false

# Unseal keys on stdin, not as arguments (visible in `ps`). See install.sh
# for the vault_keys format; three keys meet the 5/3 threshold.
# Sunbeam reopens /dev/tty after reading "-": without a terminal (cron,
# systemd) fall back to the argument.
for key in $(awk '/^Unseal keys:/ {f=1; next} /^$/ {f=0} f' "$KEYS" | head -3); do
  if { : </dev/tty; } 2>/dev/null; then
    printf '%s\n' "$key" | sunbeam vault unseal -
  else
    sunbeam vault unseal "$key"
  fi
done

# Debug aid: show the SANs on ovn-central's certificate request.
# juju show-unit ovn-central/0 --endpoint certificates --format yaml | yq -r '."ovn-central/0"."relation-info"[0]."application-data".certificates' | jq -r '.[0].certificate_signing_request' | openssl req -text | egrep "Address|Subject"
