# resource "openstack_networking_floatingip_v2" "jenkins-floatip_1" {
#   pool = data.openstack_networking_network_v2.external_network.name
# }


# resource "openstack_compute_floatingip_associate_v2" "jenkins-floatip-ass_1" {
#   floating_ip = openstack_networking_floatingip_v2.jenkins-floatip_1.address
#   instance_id = openstack_compute_instance_v2.jenkins-instance.id
# }

# We don't have designate yet
# resource "openstack_dns_recordset_v2" "jenkins-dns-1" {
#   count = var.number_to_build
#   zone_id     = data.openstack_dns_zone_v2.this-domain.id
#   name        = "${openstack_compute_instance_v2.jenkins-instance[count.index].name}.${var.project}.${var.domain}."
#   description = "Jenkins Server"
#   ttl         = 3000
#   type        = "A"
#   records     = [openstack_compute_instance_v2.jenkins-instance[count.index].access_ip_v4]
# }


# resource "openstack_dns_recordset_v2" "jenkins-dns-2" {
#   count = var.expose == false ? 0 : var.number_to_build
#   zone_id     = data.openstack_dns_zone_v2.this-domain.id
#   name        = "${openstack_compute_instance_v2.jenkins-instance[count.index].name}-external.${var.project}.${var.domain}."
#   description = "Jenkins Server"
#   ttl         = 3000
#   type        = "A"
#   records     = [openstack_networking_floatingip_v2.jenkins-floatip_1[count.index].address]
# }