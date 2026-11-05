terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

locals {
  prefix = replace(var.name_prefix, ".", "_")
}

resource "openstack_networking_network_v2" "network" {
  name           = "${local.prefix}-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet" {
  for_each        = var.subnets
  name            = "${local.prefix}-${each.key}-subnet"
  network_id      = openstack_networking_network_v2.network.id
  cidr            = each.value
  ip_version      = 4
  dns_nameservers = var.dns_servers
}

resource "openstack_networking_router_v2" "router" {
  name                = "${local.prefix}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}

resource "openstack_networking_router_interface_v2" "subnet" {
  for_each  = openstack_networking_subnet_v2.subnet
  router_id = openstack_networking_router_v2.router.id
  subnet_id = each.value.id
}

# ---- IPv6: one routed /64 for the network ----
# Carved from the platform's tenant pool (cib-undercloud: cib-tenant-v6),
# which shares an address scope with the external network's IPv6 subnet, so
# the router forwards it with its own addresses (no NAT). OVN advertises it
# to VMs (SLAAC). Reachable from your LAN once the upstream router has a
# route for it (cib-undercloud/tools/ipv6-routes.py).

data "openstack_networking_subnetpool_v2" "ipv6" {
  count = var.ipv6_enabled ? 1 : 0
  name  = var.ipv6_subnetpool
}

resource "openstack_networking_subnet_v2" "ipv6" {
  count             = var.ipv6_enabled ? 1 : 0
  name              = "${local.prefix}-v6-subnet"
  network_id        = openstack_networking_network_v2.network.id
  ip_version        = 6
  subnetpool_id     = data.openstack_networking_subnetpool_v2.ipv6[0].id
  prefix_length     = 64
  ipv6_ra_mode      = "slaac"
  ipv6_address_mode = "slaac"
}

resource "openstack_networking_router_interface_v2" "ipv6" {
  count     = var.ipv6_enabled ? 1 : 0
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.ipv6[0].id
}

resource "openstack_compute_keypair_v2" "keypair" {
  count      = var.create_keypair ? 1 : 0
  name       = "${local.prefix}-keypair"
  public_key = var.public_key
}
