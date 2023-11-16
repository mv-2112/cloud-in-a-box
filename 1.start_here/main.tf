data "openstack_identity_endpoint_v3" "keystone_endpoint_1" {
  service_name = "keystone"
  interface    = "internal"
}

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

data "openstack_identity_role_v3" "member" {
  name = "member"
}

data "openstack_identity_role_v3" "admin" {
  name = "admin"
}

resource "openstack_identity_project_v3" "domain" {
  name        = var.domain
  description = "${var.domain} domain/tenant"
  is_domain   = true
}

resource "openstack_identity_project_v3" "builder" {
  name        = var.build_project
  description = "${var.domain} project for building resources"
  domain_id   = openstack_identity_project_v3.domain.id
}




# This is our first clever moment, take each of the elements 
# in var.app_projects and create project resources.
resource "openstack_identity_project_v3" "app_projects" {
  for_each    = toset(var.app_projects)
  name        = each.key
  description = "Sample Application ${each.key}"
  domain_id   = openstack_identity_project_v3.domain.id
}