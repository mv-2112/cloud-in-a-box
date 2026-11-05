# Environment for running the undercloud Terraform. Source it (don't execute):
#
#   source ~/cib-undercloud/env.sh            # uses bootstrap/admin_openrc
#   source ~/cib-undercloud/env.sh ~/admin_openrc
#
# Sets, in the current shell only:
#   OS_*                     from admin_openrc
#   OS_CACERT                Sunbeam CA + system CAs (so image downloads from the
#                            internet verify, as well as the cloud's own endpoints)
#   AWS_CA_BUNDLE            same bundle, for the aws provider and S3 backend
#   AWS_ACCESS_KEY_ID/...    the admin project's EC2 key, reused if one exists
#   TF_VAR_s3_endpoint, TF_VAR_cloud_ca_cert_pem
# Then checks S3 auth works.

_cib_here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_cib_openrc=${1:-$_cib_here/bootstrap/admin_openrc}

if [[ ! -f $_cib_openrc ]]; then
  echo "env.sh: openrc not found at $_cib_openrc (pass its path as the first argument)" >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck disable=SC1090
source "$_cib_openrc"

# An openrc written before `sunbeam enable tls` has an http Keystone URL and
# no CA; Keystone then redirects to https and verification fails.
if [[ $OS_AUTH_URL == http://* || -z ${OS_CACERT:-} || ! -f ${OS_CACERT:-/nonexistent} ]]; then
  echo "env.sh: $_cib_openrc predates TLS (http URL or no OS_CACERT). Regenerate it:" >&2
  echo "        (umask 077; sg snap_daemon -c 'sunbeam openrc' > $_cib_openrc)" >&2
  return 1 2>/dev/null || exit 1
fi

# --- TLS: Sunbeam CA plus system CAs ---
# openrc's OS_CACERT holds only Sunbeam's CA; with it alone the openstack
# provider can't verify cloud-images.ubuntu.com when downloading images.
_cib_sunbeam_ca=$OS_CACERT
_cib_bundle=${XDG_CONFIG_HOME:-$HOME/.config}/openstack/ca_bundle_with_system.pem
mkdir -p "$(dirname "$_cib_bundle")"
cat /etc/ssl/certs/ca-certificates.crt "$_cib_sunbeam_ca" >"$_cib_bundle"
export OS_CACERT=$_cib_bundle
export AWS_CA_BUNDLE=$_cib_bundle
export TF_VAR_cloud_ca_cert_pem
TF_VAR_cloud_ca_cert_pem=$(cat "$_cib_sunbeam_ca")

# --- S3 keys for the admin project ---
# Reuse this user's existing EC2 key for this project; create one only if none.
# Ignore ~/.aws and profiles: RGW rejects stray keys as InvalidAccessKeyId.
unset AWS_PROFILE AWS_SESSION_TOKEN AWS_DEFAULT_PROFILE
_cib_project=$(openstack token issue -f value -c project_id) || return 1 2>/dev/null || exit 1
_cib_ec2=$(openstack ec2 credentials list -f json |
  jq -c --arg p "$_cib_project" '[.[] | select(."Project ID" == $p)][0] // empty')
if [[ -z $_cib_ec2 ]]; then
  echo "env.sh: no EC2 key for this project yet, creating one"
  _cib_ec2=$(openstack ec2 credentials create -f json | jq -c '{Access: .access, Secret: .secret}')
fi
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID=$(jq -r .Access <<<"$_cib_ec2")
AWS_SECRET_ACCESS_KEY=$(jq -r .Secret <<<"$_cib_ec2")
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

export TF_VAR_s3_endpoint
TF_VAR_s3_endpoint=$(openstack endpoint list --service s3 --interface public -f value -c URL)

# --- Check ---
if command -v aws >/dev/null && aws --endpoint-url "$TF_VAR_s3_endpoint" s3 ls >/dev/null; then
  echo "env.sh: OpenStack + S3 ready (key ${AWS_ACCESS_KEY_ID:0:6}…, endpoint $TF_VAR_s3_endpoint)"
else
  echo "env.sh: S3 check failed or aws CLI missing; Terraform's S3 calls may fail" >&2
fi

unset _cib_here _cib_openrc _cib_sunbeam_ca _cib_bundle _cib_project _cib_ec2
