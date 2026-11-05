locals {
  tenant_files = fileset(var.tenants_dir, "*.yaml")
  tenants = {
    for f in local.tenant_files :
    yamldecode(file("${var.tenants_dir}/${f}")).domain => yamldecode(file("${var.tenants_dir}/${f}"))
  }
}

# Undercloud catalogue: shared security group IDs etc.
data "terraform_remote_state" "undercloud" {
  backend = "s3"
  config = {
    bucket                      = "cib-undercloud-tfstate"
    key                         = "undercloud/terraform.tfstate"
    region                      = "RegionOne"
    endpoints                   = { s3 = var.s3_endpoint }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

# Public, not internal: tenants (and their pipelines) authenticate from outside
# the control plane. The old builder_openrc used the internal endpoint.
data "openstack_identity_endpoint_v3" "keystone" {
  service_name = "keystone"
  interface    = "public"
}

data "openstack_identity_endpoint_v3" "s3" {
  service_name = "s3"
  interface    = "public"
}

# Sunbeam's own admin domain/project/user. Looked up, never created. Scoped
# to the admin domain: tenant admins can create a project or user called
# "admin" in their own domains, and an unscoped name lookup would then match
# more than one.
data "openstack_identity_project_v3" "admin_domain" {
  name      = var.admin_domain
  is_domain = true
}

data "openstack_identity_project_v3" "platform" {
  name      = var.admin_project
  domain_id = data.openstack_identity_project_v3.admin_domain.id
}

data "openstack_identity_user_v3" "platform_admin" {
  name      = var.admin_user
  domain_id = data.openstack_identity_project_v3.admin_domain.id
}

data "openstack_identity_role_v3" "persona" {
  for_each = toset(flatten(values(var.personas)))
  name     = each.key
}

module "tenant" {
  source   = "./modules/tenant"
  for_each = local.tenants

  domain      = each.value.domain
  owner       = each.value.owner
  description = try(each.value.description, each.value.domain)
  projects    = try(each.value.projects, { builder = { description = "Builder project" } })

  persona_role_ids = {
    for persona, roles in var.personas : persona => {
      for r in roles : r => data.openstack_identity_role_v3.persona[r].id
    }
  }
  # The tenant's `users:` block if it has one, else the generic defaults.
  users         = try(each.value.users, null)
  default_users = var.default_users

  platform_admin_id = var.add_platform_admin_to_tenant_groups ? data.openstack_identity_user_v3.platform_admin.id : null

  shared_security_group_ids = {
    for name in try(each.value.shared_security_groups, []) :
    name => data.terraform_remote_state.undercloud.outputs.shared_security_groups[name]
  }

  platform_project_id     = data.openstack_identity_project_v3.platform.id
  rgw_project_namespacing = data.terraform_remote_state.undercloud.outputs.rgw_project_namespacing

  keystone_url   = data.openstack_identity_endpoint_v3.keystone.url
  s3_endpoint    = data.openstack_identity_endpoint_v3.s3.url
  os_cacert_path = var.os_cacert_path

  github_enabled             = try(each.value.github.enabled, false)
  github_repository          = try(each.value.github.repository, each.value.domain)
  github_visibility          = try(each.value.github.visibility, "private")
  github_owner               = var.github_owner
  github_template_repository = var.github_template_repository
}
