output "floating_ip" {
  value = [openstack_networking_floatingip_v2.jenkins-floatip_1.address]
}

output "internal_ip" {
  value = [openstack_compute_instance_v2.jenkins-instance.access_ip_v4 ]
}

output "jenkins_login" {
  description = "The Jenkins password is:" 
  value = "admin/${random_password.jenkins_password.result}"
}

output "path_module" {
    description = "Path module"
    value = path.module
}