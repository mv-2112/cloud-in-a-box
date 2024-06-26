output "jenkins_id" {
  value = [openstack_compute_instance_v2.jenkins-instance.id ]
}

output "external_ip" {
  value = [var.lb_floating_ip]
}

output "internal_ip" {
  value = [openstack_compute_instance_v2.jenkins-instance.access_ip_v4]
}

output "jenkins_admin_login" {
  description = "The Jenkins password is:" 
  value = "admin/${random_password.jenkins_password.result}"
}

output "jenkins_builder_login" {
  description = "The Jenkins password is:" 
  value = "builder/${random_password.builder_password.result}"
}

output "path_module" {
    description = "Path module"
    value = path.module
}