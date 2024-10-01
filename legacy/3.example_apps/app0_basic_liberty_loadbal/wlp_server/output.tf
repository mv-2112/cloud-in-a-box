# output "floating_ip" {
#   count = var.number_to_build
#   value = openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address
# }

output "node_floating_ip" {
  value = [openstack_networking_floatingip_v2.wlp-floatip_1[*].address]
}


output "loadbalancer_floating_ip" {
  value = one(openstack_networking_floatingip_v2.lb_floatingip_1[*].address)
}

