resource "random_password" "password" {
  length = 16
  special = false
}

data "openstack_networking_network_v2" "external_network" {
  name = "external-network"
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