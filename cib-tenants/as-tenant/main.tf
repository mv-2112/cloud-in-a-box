# Per-tenant stage, applied once per tenant by the provision-tenants workflow
# while authenticated as THAT tenant's builder-admin (OS_* env). Everything
# here is created by the tenant's own identity, inside its own project:
#
#   1. a pipeline application credential for the tenant repo: least-privilege
#      roles, expiring, rotated every 30 days. The builder-admin password never
#      leaves the platform.
#   2. optionally, the tenant's own GitHub Actions runner VM.
#
# State: platform bucket cib-tenants-tfstate, key as-tenant/<domain>.tfstate
# (passed with -backend-config), out of the tenant's reach.

terraform {
  required_version = ">= 1.6"

  backend "s3" {
    bucket                      = "cib-tenants-tfstate"
    region                      = "RegionOne"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

# Tenant credentials from OS_* env vars (set per tenant by the workflow).
provider "openstack" {}

provider "github" {
  owner = var.github_owner
}

# ---- 1. Pipeline application credential ----

resource "time_rotating" "pipeline_credential" {
  rotation_days = var.credential_rotation_days
}

resource "openstack_identity_application_credential_v3" "pipeline" {
  name        = "github-pipeline-${formatdate("YYYYMMDD", time_rotating.pipeline_credential.rfc3339)}"
  description = "Pipeline credential for ${var.github_owner}/${var.repository}, managed by cib-tenants"

  # Least privilege: build infrastructure, nothing else. No `manager`, so the
  # pipeline can't create users or grant roles in the tenant's domain.
  roles = var.pipeline_roles

  # Magnum creates a Keystone trust when it builds a cluster, and restricted
  # application credentials can't create trusts. Unrestricted is required for
  # cluster builds; the roles above still cap what the credential holds.
  unrestricted = var.pipeline_unrestricted

  # Valid for the rotation period plus a grace window, so a credential that
  # was just replaced keeps working for any job already in flight.
  expires_at = timeadd(time_rotating.pipeline_credential.rfc3339, "${(var.credential_rotation_days + var.credential_grace_days) * 24}h")

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [time_rotating.pipeline_credential]
  }
}

resource "github_actions_secret" "pipeline" {
  for_each    = toset(["OS_APPLICATION_CREDENTIAL_ID", "OS_APPLICATION_CREDENTIAL_SECRET"])
  repository  = var.repository
  secret_name = each.key
  plaintext_value = {
    OS_APPLICATION_CREDENTIAL_ID     = openstack_identity_application_credential_v3.pipeline.id
    OS_APPLICATION_CREDENTIAL_SECRET = openstack_identity_application_credential_v3.pipeline.secret
  }[each.key]
}

# ---- 2. The tenant's own runner (optional) ----

data "github_actions_registration_token" "tenant" {
  count      = var.runner_enabled ? 1 : 0
  repository = var.repository
}

module "runner" {
  source = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/gh-runner-vm?ref=v1.1.1"
  count  = var.runner_enabled ? 1 : 0

  name                  = "${replace(var.domain, ".", "-")}-runner"
  github_repository_url = "https://github.com/${var.github_owner}/${var.repository}"
  registration_token    = data.github_actions_registration_token.tenant[0].token
  labels                = var.runner_labels
  flavor                = var.runner_flavor
  disk_gb               = var.runner_disk_gb
  cidr                  = var.runner_cidr
  ca_cert_pem           = var.ca_cert_pem
  tags                  = ["cib-tenant-runner"]
}

output "pipeline_credential" {
  value = {
    name       = openstack_identity_application_credential_v3.pipeline.name
    roles      = var.pipeline_roles
    expires_at = openstack_identity_application_credential_v3.pipeline.expires_at
    rotates_at = time_rotating.pipeline_credential.rotation_rfc3339
  }
}

output "runner" {
  value = var.runner_enabled ? {
    name       = module.runner[0].name
    labels     = module.runner[0].labels
    check_boot = module.runner[0].check_boot
  } : null
}
