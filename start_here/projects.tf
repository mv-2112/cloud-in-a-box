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


resource "openstack_compute_quotaset_v2" "builder_quota" {
  for_each             = var.sites
  project_id           = openstack_identity_project_v3.builder[each.key].id
  key_pairs            = -1
  ram                  = -1
  cores                = -1
  instances            = -1
  server_groups        = -1
  server_group_members = -1
  # fixed_ips                   = (known after apply)
  # floating_ips                = (known after apply)
  # injected_file_content_bytes = (known after apply)
  # injected_file_path_bytes    = (known after apply)
  # injected_files              = (known after apply)
  # metadata_items              = (known after apply)
  # region                      = (known after apply)
  # security_group_rules        = (known after apply)
  # security_groups             = (known after apply)
}
