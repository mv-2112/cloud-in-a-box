output "jenkins_ext_ip" {
  value = module.jenkins_server.floating_ip
}

output "jenkins_login" {
  sensitive = true
  value     = module.jenkins_server.jenkins_login
}



output "backstage_ext_ip" {
  value = module.backstage_server.external_ip
}



locals {
  ssh_key = <<-EOT
    ${openstack_compute_keypair_v2.keypair.private_key}
  EOT
}

resource "local_file" "output-ssh-key" {
  filename = "./${var.build_project}.ssh"
  content  = local.ssh_key
  file_permission = "0600"
}

