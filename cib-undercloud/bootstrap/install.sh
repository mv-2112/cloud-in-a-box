#!/usr/bin/env bash
# Single-node Sunbeam install, driven by a manifest rendered from site.env.
# No interactive prompts: every answer comes from site.env.
#
#   cp site.env.example site.env   # edit it
#   ./install.sh --check           # validate site.env against this host only
#   ./install.sh                   # install
#
# Network layout:
#   management (MGMT_CIDR)  hosts, Juju, Kubernetes, Ceph, and the OpenStack
#                           API endpoints on API_RANGE
#   VM network (EXT_*)      floating IPs and router gateways, on its own NIC/VLAN;
#                           never on the management network
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

if [[ ! -f site.env ]]; then
  echo "site.env not found: cp site.env.example site.env and edit it" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. ./site.env
set +a
NODE_FQDN=$(hostname -f)
export NODE_FQDN

if [[ ${1:-} == "--check" ]]; then
  exec python3 -I render_manifest.py --check-only
fi

# 1. Validate and render manifest.yaml + ../terraform/site.auto.tfvars.json
python3 -I render_manifest.py

# 2. Snap and node preparation
sudo snap install openstack --channel "$RELEASE"
sunbeam prepare-node-script --bootstrap | bash -x

# prepare-node-script adds us to snap_daemon; this shell doesn't have the
# group yet (the old `newgrp` started a new interactive shell and stalled the
# script), so run sunbeam through `sg`.
sb() { sg snap_daemon -c "$(printf '%q ' sunbeam "$@")"; }

# 3. Bootstrap and configure from the manifest
sb cluster bootstrap --role control,compute,storage,network \
  --manifest "$HERE/manifest.yaml" --accept-defaults
sb configure --manifest "$HERE/manifest.yaml" --accept-defaults

# Secrets this script writes (admin_openrc, vault_keys, certs/) are created
# readable by this user only. umask is scoped to those commands: a global one
# would leak into the sudo'd bootstrap steps. admin_openrc is written after
# TLS is enabled (step 4): before that, its Keystone URL is plain http and it
# has no OS_CACERT.

# 4. Vault and secrets
sb enable vault
# vault_keys holds all 5 unseal keys AND the root token, on the same host as
# the vault they protect; fixups/post_reboot.sh needs it to unseal after a
# reboot. Acceptable for a single-box lab; anywhere else, keep these offline
# and split the unseal keys between people.
(umask 077; sb vault init 5 3 > ./vault_keys)
sudo chattr +i ./vault_keys

# vault_keys is `sunbeam vault init`'s default output:
#   Unseal keys:            <- then one key per line, then a blank line
#   Root token: hvs.xxxx
# Keys and token go to sunbeam on stdin ("-"), never as arguments (those are
# visible to every user in `ps`). Three keys meet the 5/3 threshold.
# Sunbeam reopens /dev/tty after reading "-", so without a terminal (cron,
# systemd) fall back to the argument.
unseal_keys() { awk '/^Unseal keys:/ {f=1; next} /^$/ {f=0} f' ./vault_keys; }
root_token()  { awk '/^Root token:/ {print $3}' ./vault_keys; }
have_tty()    { { : </dev/tty; } 2>/dev/null; }
vault_secret() {   # vault_secret <subcommand> <secret>
  if have_tty; then printf '%s\n' "$2" | sb vault "$1" -; else sb vault "$1" "$2"; fi
}
for key in $(unseal_keys | head -3); do vault_secret unseal "$key"; done
vault_secret authorize-charm "$(root_token)"

sb enable secrets
sb enable tls self-signed --endpoint public --endpoint internal --endpoint rgw

# Now that the endpoints are https: the openrc carries the https Keystone URL
# and OS_CACERT (Sunbeam's CA).
(umask 077; sb openrc > admin_openrc)

# 5. Load balancer (Octavia on OVN)
sb enable loadbalancer
sudo snap set openstack feature.microovn-sdn=true
sudo snap set openstack ovn.provider=microovn
sb loadbalancer configure

mkdir -m 700 -p certs
(umask 077; openssl genrsa -out certs/ca.key 2048)
# Private CA for Octavia only (amphora controller cert + issuing CA below).
# Octavia checks signatures, not names, so the CN is just a label.
openssl req -new -x509 -days 3650 -key certs/ca.key -out certs/ca.crt \
  -subj "/C=GB/O=cloud-in-a-box/CN=${CLOUD_NAME:-$(hostname -s)} Octavia CA"

cd certs

cat <<EOF >./leaf.ext
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOF

cat <<EOF >./ca_ext.ext
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
EOF

# Certificate signing requests for Octavia
sb loadbalancer list_outstanding_csrs --format yaml | yq '.[]' - -r --split-exp=' .endpoint + ".csr.yaml"'
for f in ./amphora*.csr.yaml; do
  yq ' .csr ' "$f" >"./$(basename "$f" .yaml)"
done

# -CAcreateserial on the first signature: ca.srl doesn't exist yet, and the
# old script's plain -CAserial failed here.
# Validity nests inside the root CA's 10 years: issuing CA 5 years, controller
# cert 3 years (Octavia renews the per-amphora certs itself, inside the
# issuing CA's life). Re-sign the controller cert before it expires, or
# Octavia can no longer manage existing load balancers.
openssl x509 -req -days 1095 \
  -in amphora-controller-cert.csr \
  -CA ca.crt -CAkey ca.key -CAserial ca.srl -CAcreateserial \
  -out amphora-controller-cert.crt \
  -extfile leaf.ext

openssl x509 -req -days 1825 \
  -in amphora-issuing-ca.csr \
  -CA ca.crt -CAkey ca.key -CAserial ca.srl \
  -out amphora-issuing-ca.crt \
  -extfile ca_ext.ext

# Hand the signed certificates to Octavia. provide_certificates asks, for
# each of the two CSRs (its prompt names the endpoint):
#   1. the signed certificate     -> that endpoint's .crt below
#   2. the CA certificate         -> ca.crt (it signed both)
#   3. the CA chain (optional)    -> leave empty: ca.crt is self-signed
cat <<EOF

=== Answers for 'sunbeam loadbalancer provide_certificates' (base64) ===

endpoint amphora-controller-cert
  certificate:     $(base64 -w0 amphora-controller-cert.crt)
  CA certificate:  $(base64 -w0 ca.crt)
  CA chain:        (leave empty)

endpoint amphora-issuing-ca
  certificate:     $(base64 -w0 amphora-issuing-ca.crt)
  CA certificate:  $(base64 -w0 ca.crt)
  CA chain:        (leave empty)

EOF
sb loadbalancer provide_certificates

cd "$HERE"

# 6. Container infrastructure (Magnum)
sb enable caas

cat <<EOF

Sunbeam is up. Next:
  source $HERE/admin_openrc
  cd ../terraform && terraform init && terraform apply
    (site.auto.tfvars.json already carries the external network and region;
     the undercloud creates the external network and flavors, because the
     demo setup that normally does is switched off)
EOF
