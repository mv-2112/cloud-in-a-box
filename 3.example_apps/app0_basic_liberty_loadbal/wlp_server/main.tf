data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

data "openstack_networking_subnet_v2" "wlp_network" {
  name = "${var.project}-subnet-1"
}

data "openstack_dns_zone_v2" "this-domain" {
  name        = "${var.project}.${var.domain}."
}