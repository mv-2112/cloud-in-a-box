

resource "openstack_networking_floatingip_v2" "gke-master-floatip_1" {
  count = var.expose == false ? 0 : var.gke_master_number_to_build
  pool  = data.openstack_networking_network_v2.external_network.name
}


resource "openstack_compute_floatingip_associate_v2" "gke-master--floatip-ass_1" {
  count       = var.expose == false ? 0 : var.gke_master_number_to_build
  floating_ip = openstack_networking_floatingip_v2.gke-master-floatip_1[count.index].address
  instance_id = openstack_compute_instance_v2.gke-master-instance[count.index].id
}


resource "openstack_dns_recordset_v2" "gke-master-dns-1" {
  count       = var.gke_master_number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.gke-master-instance[count.index].name}.${var.project}.${var.domain}."
  description = "GKE Master Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_compute_instance_v2.gke-master-instance[count.index].access_ip_v4]
}


resource "openstack_dns_recordset_v2" "gke-master-dns-2" {
  count       = var.expose == false ? 0 : var.gke_master_number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.gke-master-instance[count.index].name}-external.${var.project}.${var.domain}."
  description = "GKE Master Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_networking_floatingip_v2.gke-master-floatip_1[count.index].address]
}


resource "openstack_networking_floatingip_v2" "gke-node-floatip_1" {
  count = var.expose == false ? 0 : var.gke_node_number_to_build
  pool  = data.openstack_networking_network_v2.external_network.name
}


resource "openstack_compute_floatingip_associate_v2" "gke-node--floatip-ass_1" {
  count       = var.expose == false ? 0 : var.gke_node_number_to_build
  floating_ip = openstack_networking_floatingip_v2.gke-node-floatip_1[count.index].address
  instance_id = openstack_compute_instance_v2.gke-node-instance[count.index].id
}


resource "openstack_dns_recordset_v2" "gke-node-dns-1" {
  count       = var.gke_node_number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.gke-node-instance[count.index].name}.${var.project}.${var.domain}."
  description = "GKE Node Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_compute_instance_v2.gke-node-instance[count.index].access_ip_v4]
}


resource "openstack_dns_recordset_v2" "gke-node-dns-2" {
  count       = var.expose == false ? 0 : var.gke_node_number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.gke-node-instance[count.index].name}-external.${var.project}.${var.domain}."
  description = "GKE Node Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_networking_floatingip_v2.gke-node-floatip_1[count.index].address]
}