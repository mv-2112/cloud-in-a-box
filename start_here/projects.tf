resource "openstack_identity_project_v3" "domain" {
  for_each    = var.sites
  name        = each.key
  description = "${each.value.description} (Owner: ${each.value.owner})"
  is_domain   = true
}

resource "openstack_identity_project_v3" "builder" {
  for_each    = var.sites
  name        = "builder"
  description = "${each.key} builder project"
  domain_id   = openstack_identity_project_v3.domain[each.key].id
  parent_id   = openstack_identity_project_v3.domain[each.key].id
}