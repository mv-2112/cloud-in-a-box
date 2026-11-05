#!/usr/bin/env bash
# Apply (or plan) the as-tenant stage once per tenant, each time authenticated
# as that tenant's builder-admin rather than the platform admin. It manages the
# tenant repo's pipeline credential and, if enabled, the tenant's runner VM.
#
#   as-tenant/apply-all.sh plan    # PR: plan for tenants that already exist
#   as-tenant/apply-all.sh apply   # main: create/update; destroy if github.enabled is false
#
# Expects in the environment: S3_ENDPOINT, AWS_* (platform state creds),
# GITHUB_TOKEN, TF_VAR_github_owner. Reads targets from ../terraform state.
set -euo pipefail

MODE=${1:?usage: apply-all.sh plan|apply}
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

# Only tenants already in state have credentials; new ones are picked up on
# the run that creates them (apply runs after the tenants apply).
TARGETS=$(terraform -chdir=../terraform output -json tenant_stage_targets 2>/dev/null || echo '{}')
[ -n "$TARGETS" ] || TARGETS='{}'

failed=()
for domain in $(jq -r 'keys[]' <<<"$TARGETS"); do
  t=$(jq -c --arg d "$domain" '.[$d]' <<<"$TARGETS")
  # Not `// empty`: that would turn a real `false` into an empty string.
  get() { jq -r --arg k "$1" '.[$k] | if . == null then empty else . end' <<<"$t"; }

  pw=$(get os_password)
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::add-mask::$pw"

  echo "::group::as-tenant stage for $domain ($MODE)"
  if ! (
    # Drop the platform admin's credentials; use the tenant's.
    unset OS_AUTH_TYPE OS_APPLICATION_CREDENTIAL_ID OS_APPLICATION_CREDENTIAL_SECRET OS_CLOUD
    export OS_AUTH_URL=$(get os_auth_url)
    export OS_USERNAME=$(get os_username)
    export OS_PASSWORD=$pw
    export OS_USER_DOMAIN_NAME=$(get os_user_domain_name)
    export OS_PROJECT_DOMAIN_NAME=$(get os_project_domain_name)
    export OS_PROJECT_NAME=$(get os_project_name)
    export OS_IDENTITY_API_VERSION=3
    export TF_VAR_domain=$domain
    export TF_VAR_repository=$(get repository)
    export TF_VAR_runner_enabled=$(get runner_enabled)
    export TF_VAR_runner_flavor=$(get runner_flavor)
    ca=$(get ca_cert_pem); [ -n "$ca" ] && export TF_VAR_ca_cert_pem=$ca

    terraform init -input=false -reconfigure \
      -backend-config="key=as-tenant/$domain.tfstate" \
      -backend-config="endpoints={s3=\"$S3_ENDPOINT\"}" >/dev/null

    if [ "$(get enabled)" = "true" ]; then
      case $MODE in
        plan)  terraform plan -input=false ;;
        apply) terraform apply -input=false -auto-approve ;;
      esac
    elif [ -n "$(terraform state list 2>/dev/null)" ]; then
      case $MODE in
        plan)  terraform plan -input=false -destroy ;;
        apply) terraform destroy -input=false -auto-approve ;;
      esac
    else
      echo "no tenant repo, nothing deployed"
    fi
  ); then
    failed+=("$domain")
  fi
  echo "::endgroup::"
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "as-tenant $MODE failed for: ${failed[*]}"
  exit 1
fi
