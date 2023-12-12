output "floating_ip" {
  count = var.number_to_build
  value = openstack_networking_floatingip_v2.gke-floatip_1[count.index].address
}

