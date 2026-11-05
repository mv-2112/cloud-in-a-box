# Tenant repo created from the template, with everything its pipeline needs
# written in as Actions variables/secrets. Replaces the old local
# builder_openrc / aws_config / aws_credentials files under ../sites/.

resource "github_repository" "tenant" {
  count       = var.github_enabled ? 1 : 0
  name        = var.github_repository
  description = "Infrastructure for ${var.domain} (Owner: ${var.owner})"
  visibility  = var.github_visibility

  template {
    owner      = var.github_owner
    repository = var.github_template_repository
  }

  lifecycle {
    # Template is only used at creation; don't recreate if the template changes.
    ignore_changes = [template]
  }
}

resource "github_repository_environment" "production" {
  count       = var.github_enabled ? 1 : 0
  repository  = github_repository.tenant[0].name
  environment = "production"
}

resource "github_repository_environment" "plan" {
  count       = var.github_enabled ? 1 : 0
  repository  = github_repository.tenant[0].name
  environment = "plan"
}

locals {
  gh_variables = {
    TENANT_DOMAIN   = var.domain
    OS_AUTH_URL     = var.keystone_url
    OS_CACERT_PATH  = var.os_cacert_path
    S3_ENDPOINT     = var.s3_endpoint
    TF_STATE_BUCKET = module.state_bucket.grantee_bucket_name
  }
}

resource "github_actions_variable" "tenant" {
  for_each      = var.github_enabled ? local.gh_variables : {}
  repository    = github_repository.tenant[0].name
  variable_name = each.key
  value         = each.value
}

# S3 keys for the state bucket. The OpenStack credential is NOT written here:
# the as-tenant stage writes an expiring, role-limited application credential
# (OS_APPLICATION_CREDENTIAL_ID/SECRET). builder-admin's password never
# reaches the repo.
#
# Secret values are known only after apply, so they can't be for_each keys;
# the keys are static and the values are looked up inside.
resource "github_actions_secret" "tenant" {
  for_each    = var.github_enabled ? toset(["S3_ACCESS_KEY", "S3_SECRET_KEY"]) : toset([])
  repository  = github_repository.tenant[0].name
  secret_name = each.key
  plaintext_value = {
    S3_ACCESS_KEY = openstack_identity_ec2_credential_v3.builder_admin.access
    S3_SECRET_KEY = openstack_identity_ec2_credential_v3.builder_admin.secret
  }[each.key]
}
