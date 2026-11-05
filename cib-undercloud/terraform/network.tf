# The external network: where floating IPs and router gateways come from.
#
# Sunbeam's demo setup normally creates this, but it is switched off (no demo
# user or project), so the platform owns it here. It maps to physnet1, which
# Sunbeam bridged onto the dedicated VM NIC/VLAN from bootstrap/site.env, and
# never touches the management network.

resource "openstack_networking_network_v2" "external" {
  name           = var.external_network
  admin_state_up = true
  external       = true
  # Visible to every project, but only usable through routers and floating IPs.
  shared = false
  tags   = [local.platform_tag]

  segments {
    physical_network = "physnet1"
    network_type     = var.external_network_config.network_type
    segmentation_id  = var.external_network_config.network_type == "vlan" ? var.external_network_config.segmentation_id : null
  }

  lifecycle {
    precondition {
      condition     = contains(["flat", "vlan"], var.external_network_config.network_type)
      error_message = "external_network_config.network_type must be flat or vlan."
    }
    precondition {
      condition     = var.external_network_config.network_type != "vlan" || var.external_network_config.segmentation_id != null
      error_message = "A vlan external network needs segmentation_id."
    }
  }
}

resource "openstack_networking_subnet_v2" "external" {
  name        = "external-subnet"
  network_id  = openstack_networking_network_v2.external.id
  cidr        = var.external_network_config.cidr
  ip_version  = 4
  gateway_ip  = var.external_network_config.gateway
  enable_dhcp = false
  tags        = [local.platform_tag]

  allocation_pool {
    start = split("-", var.external_network_config.range)[0]
    end   = split("-", var.external_network_config.range)[1]
  }
}

# ---- IPv6 ----
#
# VM-side IPv6 is routed, never NATed (management stays single-stack; see
# bootstrap/site.env). Two pools share one address scope:
#
#   cib-external-v6  the VM VLAN's stable ULA /64 (EXT_V6_CIDR). Tenant routers
#                    get their gateway address here; the upstream router (RB4011)
#                    sends the router advertisements on this VLAN.
#   cib-tenant-v6    TENANT_V6_POOL, carved into a /64 per tenant network. The
#                    project default, so `--use-default-subnet-pool` and the
#                    tenant-network module pick it up.
#
# Same address scope = Neutron routes tenant /64s straight out through the
# tenant router with their own addresses. The RB4011 needs a return route per
# tenant network: tools/ipv6-routes.py generates them.

locals {
  ipv6_enabled        = var.external_network_config.ipv6_cidr != null
  tenant_ipv6_enabled = local.ipv6_enabled && var.tenant_ipv6_pool != null
}

resource "openstack_networking_addressscope_v2" "v6" {
  count      = local.ipv6_enabled ? 1 : 0
  name       = "cib-v6"
  ip_version = 6
  shared     = true
}

resource "openstack_networking_subnetpool_v2" "external_v6" {
  count             = local.ipv6_enabled ? 1 : 0
  name              = "cib-external-v6"
  ip_version        = 6
  prefixes          = [var.external_network_config.ipv6_cidr]
  default_prefixlen = 64
  min_prefixlen     = 64
  max_prefixlen     = 64
  address_scope_id  = openstack_networking_addressscope_v2.v6[0].id
  shared            = false # only the platform carves from it
  tags              = [local.platform_tag]
}

resource "openstack_networking_subnet_v2" "external_v6" {
  count         = local.ipv6_enabled ? 1 : 0
  name          = "external-subnet-v6"
  network_id    = openstack_networking_network_v2.external.id
  subnetpool_id = openstack_networking_subnetpool_v2.external_v6[0].id
  cidr          = var.external_network_config.ipv6_cidr
  ip_version    = 6
  gateway_ip    = var.external_network_config.ipv6_gateway
  # The RB4011 sends router advertisements on this VLAN; Neutron only assigns
  # router gateway ports their SLAAC (EUI-64) addresses, it doesn't advertise.
  ipv6_address_mode = "slaac"
  tags              = [local.platform_tag]
}

resource "openstack_networking_subnetpool_v2" "tenant_v6" {
  count             = local.tenant_ipv6_enabled ? 1 : 0
  name              = "cib-tenant-v6"
  ip_version        = 6
  prefixes          = [var.tenant_ipv6_pool]
  default_prefixlen = 64
  min_prefixlen     = 64
  max_prefixlen     = 64
  address_scope_id  = openstack_networking_addressscope_v2.v6[0].id
  shared            = true
  is_default        = true
  tags              = [local.platform_tag]
}
