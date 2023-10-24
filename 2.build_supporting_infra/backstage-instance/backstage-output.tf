# output "floating_ip" {
#   value = [openstack_networking_floatingip_v2.backstage-floatip_1.address]
# }

output "internal_ip" {
  value = [openstack_compute_instance_v2.backstage-instance.access_ip_v4 ]
}

output "external_ip" {
  value = [openstack_networking_floatingip_v2.backstage-floatip_1.address ]
}


output "backstage_admin_login" {
  sensitive = true
  description = "The backstage password is:" 
  value = "admin/${random_password.backstage_password.result}"
}

output "path_module" {
    description = "Path module"
    value = path.module
}
