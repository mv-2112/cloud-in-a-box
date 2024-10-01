# resource "openstack_dns_zone_v2" "builder_domain" {
#   name        = "builder.${var.domain}."
#   project_id  = openstack_identity_project_v3.builder.id
#   email       = "root@${var.domain}"
#   description = "${var.domain} zone"
#   ttl         = 3000
#   type        = "PRIMARY"
# }

# resource "openstack_dns_zone_v2" "app_domain" {
#   for_each    = toset(var.app_projects)
#   name        = "${each.key}.${var.domain}."
#   project_id  = openstack_identity_project_v3.app_projects[each.key].id
#   email       = "root@${var.domain}"
#   description = "${var.domain} zone"
#   ttl         = 3000
#   type        = "PRIMARY"
# }
