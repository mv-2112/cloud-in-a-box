output "pub_keypair" {
  value = openstack_compute_keypair_v2.keypair.public_key
}

output "priv_keypair" {
  value = openstack_compute_keypair_v2.keypair.private_key
  sensitive = true
}


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



# Produce a file containing the app0 url and access details

output "app0_message" {
  value = "Information on your app0 install is contained in ${var.app_project}-app0.txt"
}


resource "local_file" "app0-details" {
  filename = "./appinfo/app0.txt"
  content  = <<-EOT
  URL: http://${module.wlp_server.loadbalancer_floating_ip}
  EOT
  file_permission = "0600"
}
