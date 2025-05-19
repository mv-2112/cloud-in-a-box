data "openstack_identity_endpoint_v3" "keystone_endpoint" {
  service_name = "keystone"
  interface    = "internal"
}

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

data "openstack_identity_user_v3" "uber_admin" {
  name = "admin"
}

data "openstack_identity_project_v3" "admin_domain" {
  name      = "admin_domain"
  is_domain = true
}

data "openstack_identity_role_v3" "member" {
  name = "member"
}

data "openstack_identity_role_v3" "manager" {
  name = "manager"
}

data "openstack_identity_role_v3" "admin" {
  name = "admin"
}

data "openstack_identity_role_v3" "load-balancer_member" {
  name = "load-balancer_member"
}

data "openstack_identity_role_v3" "heat_stack_user" {
  name = "heat_stack_user"
}