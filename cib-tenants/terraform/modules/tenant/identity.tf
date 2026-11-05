terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
    github = {
      source = "integrations/github"
    }
    random = {
      source = "hashicorp/random"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  safe_name       = replace(var.domain, ".", "-")
  primary_project = contains(keys(var.projects), "builder") ? "builder" : sort(keys(var.projects))[0]
  users           = var.users != null ? var.users : var.default_users
}

resource "openstack_identity_project_v3" "domain" {
  name        = var.domain
  description = "${var.description} (Owner: ${var.owner})"
  is_domain   = true
}

resource "openstack_identity_project_v3" "project" {
  for_each    = var.projects
  name        = each.key
  description = coalesce(each.value.description, "${var.domain} ${each.key} project")
  domain_id   = openstack_identity_project_v3.domain.id
  parent_id   = openstack_identity_project_v3.domain.id
}

# ---- builder-admin: the identity behind the tenant's automation ----
# Its password is used only by the platform (the as-tenant stage logs in as
# it). The tenant repo gets an expiring, role-limited application credential
# minted from it instead, never the password.

resource "random_password" "builder_admin" {
  length  = 32
  special = false
}

resource "openstack_identity_user_v3" "builder_admin" {
  name               = "builder-admin"
  description        = "Automation identity for ${var.domain} (managed by cib-tenants; not for humans)"
  domain_id          = openstack_identity_project_v3.domain.id
  default_project_id = openstack_identity_project_v3.project[local.primary_project].id
  password           = random_password.builder_admin.result

  # A service identity: exempt from forced password change and expiry.
  ignore_change_password_upon_first_use = true
  ignore_password_expiry                = true
}

# EC2 (S3) credentials for builder-admin, used by the tenant pipeline for its
# state bucket. (The old code omitted user_id, which creates the credential
# for the *authenticating* user, i.e. the cloud admin.)
resource "openstack_identity_ec2_credential_v3" "builder_admin" {
  user_id    = openstack_identity_user_v3.builder_admin.id
  project_id = openstack_identity_project_v3.project[local.primary_project].id
}

# ---- personas: one group per persona, roles granted to groups only ----
#
# Roles are assigned to groups, never directly to users, and inherited on the
# domain so they apply to every project in it, present and future.

locals {
  persona_role_pairs = { for pair in flatten([
    for persona, roles in var.persona_role_ids : [
      for role, id in roles : { key = "${persona}/${role}", persona = persona, role_id = id }
    ]
  ]) : pair.key => pair }
}

resource "openstack_identity_group_v3" "persona" {
  for_each    = var.persona_role_ids
  name        = "${var.domain}_${each.key}"
  description = "${var.domain} ${each.key}s: ${join(", ", sort(keys(each.value)))}"
  domain_id   = openstack_identity_project_v3.domain.id
}

resource "openstack_identity_inherit_role_assignment_v3" "persona" {
  for_each  = local.persona_role_pairs
  group_id  = openstack_identity_group_v3.persona[each.value.persona].id
  domain_id = openstack_identity_project_v3.domain.id
  role_id   = each.value.role_id
}

# builder-admin builds infrastructure: developer, not admin. It can't create
# users or hand out roles.
resource "openstack_identity_user_membership_v3" "builder_admin" {
  user_id  = openstack_identity_user_v3.builder_admin.id
  group_id = openstack_identity_group_v3.persona[var.automation_persona].id

  lifecycle {
    precondition {
      # RGW only accepts member/Member, and the pipeline needs its state bucket.
      condition     = contains(keys(var.persona_role_ids[var.automation_persona]), "member")
      error_message = "The automation persona (${var.automation_persona}) must include the member role."
    }
  }
}

resource "openstack_identity_user_membership_v3" "platform_admin" {
  count    = var.platform_admin_id == null ? 0 : 1
  user_id  = var.platform_admin_id
  group_id = openstack_identity_group_v3.persona["admin"].id
}

# ---- people ----

resource "random_password" "user" {
  for_each = local.users
  length   = 20
  special  = true
  # Characters that survive copy/paste and shell quoting.
  override_special = "-_.,+="
}

resource "openstack_identity_user_v3" "user" {
  for_each    = local.users
  name        = each.key
  description = coalesce(each.value.description, "${each.value.persona} for ${var.domain}")
  domain_id   = openstack_identity_project_v3.domain.id
  enabled     = each.value.enabled

  default_project_id = openstack_identity_project_v3.project[local.primary_project].id
  password           = random_password.user[each.key].result
  extra              = each.value.email != null ? { email = each.value.email } : {}

  # Initial password only: users must change it at first login (when Keystone's
  # security_compliance.change_password_upon_first_use is on), and Terraform
  # must not set it back afterwards.
  ignore_change_password_upon_first_use = false

  lifecycle {
    ignore_changes = [password]
  }
}

resource "openstack_identity_user_membership_v3" "user" {
  for_each = local.users
  user_id  = openstack_identity_user_v3.user[each.key].id
  group_id = openstack_identity_group_v3.persona[each.value.persona].id

  lifecycle {
    precondition {
      condition     = contains(keys(var.persona_role_ids), each.value.persona)
      error_message = "User ${each.key} has persona \"${each.value.persona}\"; valid personas: ${join(", ", keys(var.persona_role_ids))}."
    }
  }
}

# ---- quotas ----

resource "openstack_compute_quotaset_v2" "project" {
  for_each             = { for k, v in var.projects : k => v if v.quota != null }
  project_id           = openstack_identity_project_v3.project[each.key].id
  cores                = lookup(each.value.quota, "cores", null)
  ram                  = lookup(each.value.quota, "ram", null)
  instances            = lookup(each.value.quota, "instances", null)
  key_pairs            = lookup(each.value.quota, "key_pairs", null)
  server_groups        = lookup(each.value.quota, "server_groups", null)
  server_group_members = lookup(each.value.quota, "server_group_members", null)
}

# ---- shared platform security groups (from cib-undercloud) ----

resource "openstack_networking_rbac_policy_v2" "shared_sg" {
  for_each = { for pair in setproduct(keys(var.projects), keys(var.shared_security_group_ids)) :
    "${pair[0]}/${pair[1]}" => { project = pair[0], sg = pair[1] }
  }
  action        = "access_as_shared"
  object_type   = "security_group"
  object_id     = var.shared_security_group_ids[each.value.sg]
  target_tenant = openstack_identity_project_v3.project[each.value.project].id
}

# ---- Terraform state bucket ----
# Owned by the platform admin project; the tenant's primary project (where
# builder-admin's EC2 credentials are scoped) gets object read/write only.
# The tenant can't delete it, make it public, change its policy or disable
# versioning, and no other tenant is granted anything.

module "state_bucket" {
  source = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/state-bucket?ref=v1.1.1"

  name                    = "${local.safe_name}-tfstate"
  grant_project_ids       = [openstack_identity_project_v3.project[local.primary_project].id]
  rgw_project_namespacing = var.rgw_project_namespacing
  owner_project_id        = var.platform_project_id
  tags = {
    managed-by = "cib-tenants"
    tenant     = var.domain
  }
}
