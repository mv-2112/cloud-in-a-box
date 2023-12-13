# output "floating_ip" {
#   count = var.number_to_build
#   value = openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address
# }

output "floating_ip" {
  value = [openstack_networking_floatingip_v2.wlp-floatip_1[*].address]

}

