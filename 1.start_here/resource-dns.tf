resource "openstack_dns_zone_v2" "builder_domain" {
  name        = "builder.${var.domain}."
  project_id  = openstack_identity_project_v3.builder.id
  email       = "root@${var.domain}"
  description = "${var.domain} zone"
  ttl         = 3000
  type        = "PRIMARY"
}
