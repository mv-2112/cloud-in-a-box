
# Sunbeam's own admin domain/project/user. Looked up, never created. Scoped
# to the admin domain: tenant admins can create a project or user called
# "admin" in their own domains, and an unscoped name lookup would then match
# more than one.
data "openstack_identity_project_v3" "admin_domain" {
  name      = var.admin_domain
  is_domain = true
}

data "openstack_identity_project_v3" "admin_project" {
  name      = var.admin_project
  domain_id = data.openstack_identity_project_v3.admin_domain.id
}

locals {
  # Everything the undercloud publishes is tagged so tenants (and humans) can
  # tell platform-owned objects from their own.
  platform_tag = "cib-platform"
}
