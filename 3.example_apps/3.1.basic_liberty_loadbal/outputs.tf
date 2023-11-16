output "pub_keypair" {
  value = openstack_compute_keypair_v2.keypair.public_key
}

output "priv_keypair" {
  value = openstack_compute_keypair_v2.keypair.private_key
  sensitive = true
}

# output "jenkins_ext_ip" {
#   value = module.jenkins_server.floating_ip
# }

# output "chef_ext_ip" {
#   value = module.chef_server.floating_ip
# }


locals {
  ssh_key = <<-EOT
    ${openstack_compute_keypair_v2.keypair.private_key}
  EOT
}

resource "local_file" "output-ssh-key" {
  filename = "./${var.app_project}.ssh"
  content  = local.ssh_key
  file_permission = "0600"
}
