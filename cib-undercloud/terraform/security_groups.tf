# "Core" security groups owned by the admin project.
#
# Neutron security groups are project-scoped, so tenants can't see these by
# default. They are made usable in tenant projects with Neutron RBAC
# (object_type = "security_group", action = "access_as_shared"). The RBAC
# entries are created per tenant project by the cib-tenants provisioner, so a
# tenant only gets the groups its definition asks for. Set
# share_security_groups_with_all = true to share them with every project instead.
#
# Tenants can attach shared groups to ports but cannot modify their rules.

locals {
  sg_rules = { for r in flatten([
    for sg_name, sg in var.shared_security_groups : [
      for idx, rule in sg.rules : merge(rule, { sg = sg_name, key = "${sg_name}-${idx}" })
    ]
  ]) : r.key => r }
}

resource "openstack_networking_secgroup_v2" "shared" {
  for_each             = var.shared_security_groups
  name                 = "cib-${each.key}"
  description          = each.value.description
  tenant_id            = data.openstack_identity_project_v3.admin_project.id
  delete_default_rules = true
  tags                 = [local.platform_tag]
}

resource "openstack_networking_secgroup_rule_v2" "shared" {
  for_each          = local.sg_rules
  security_group_id = openstack_networking_secgroup_v2.shared[each.value.sg].id
  tenant_id         = data.openstack_identity_project_v3.admin_project.id
  direction         = each.value.direction
  ethertype         = each.value.ethertype
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  description       = each.value.description
}

resource "openstack_networking_rbac_policy_v2" "shared_all" {
  for_each      = var.share_security_groups_with_all ? var.shared_security_groups : {}
  action        = "access_as_shared"
  object_id     = openstack_networking_secgroup_v2.shared[each.key].id
  object_type   = "security_group"
  target_tenant = "*"
}
