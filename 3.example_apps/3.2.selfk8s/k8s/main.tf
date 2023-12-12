data "openstack_networking_network_v2" "external_network" {
  name = "ext_net"
}

data "openstack_dns_zone_v2" "this-domain" {
  name        = "${var.project}.${var.domain}."
}