resource "openstack_networking_network_v2" "network" {
  name           = "example_com-network"
  admin_state_up = "true"
}


resource "openstack_networking_subnet_v2" "subnet" {
  name                 = "example_com-subnet-1"
  network_id           = openstack_networking_network_v2.network.id
  cidr                 = "192.168.1.0/24"
  ip_version           = 4
  dns_nameservers      = var.dns_servers
}


resource "openstack_networking_router_v2" "router_1" {
  name                = "example_com-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}


resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = openstack_networking_router_v2.router_1.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}
