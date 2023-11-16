resource "openstack_networking_network_v2" "builder_network" {
  name           = "${var.build_project}-${var.domain}-network"
  admin_state_up = true
  tenant_id      = openstack_identity_project_v3.builder.id
}


resource "openstack_networking_subnet_v2" "builder_subnet" {
  name       = "${var.build_project}-subnet-1"
  network_id = openstack_networking_network_v2.builder_network.id
  cidr       = "192.168.99.0/24"
  ip_version = 4
  tenant_id  = openstack_identity_project_v3.domain.id
}

resource "openstack_networking_router_v2" "builder_router_1" {
  name                = "${var.build_project}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
  # external_network_id = data.openstack_networking_network_v2.external_network.id
  tenant_id = openstack_identity_project_v3.builder.id
}

resource "openstack_networking_router_interface_v2" "builder_router_interface_1" {
  router_id = openstack_networking_router_v2.builder_router_1.id
  subnet_id = openstack_networking_subnet_v2.builder_subnet.id
}


resource "openstack_networking_network_v2" "network" {
  for_each       = toset(var.app_projects)
  name           = "${each.key}-${var.domain}-network"
  admin_state_up = "true"
  tenant_id      = openstack_identity_project_v3.app_projects[each.key].id
}



resource "openstack_networking_subnet_v2" "subnet" {
  for_each   = toset(var.app_projects)
  name       = "${each.key}-subnet-1"
  network_id = openstack_networking_network_v2.network[each.key].id
  cidr       = "192.168.${100 + index(var.app_projects, each.key)}.0/24"
  ip_version = 4
  # dns_nameservers = var.dns_server
  tenant_id = each.key
}

resource "openstack_networking_router_v2" "app_router_1" {
  for_each            = toset(var.app_projects)
  name                = "${each.key}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
  tenant_id           = openstack_identity_project_v3.app_projects[each.key].id
}

resource "openstack_networking_router_interface_v2" "app_router_interface_1" {
  for_each  = toset(var.app_projects)
  router_id = openstack_networking_router_v2.app_router_1[each.key].id
  subnet_id = openstack_networking_subnet_v2.subnet[each.key].id
}


