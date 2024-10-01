# Produce a file containing the Jenkins url and access details

output "jenkins_message" {
  value = "Information on your Jenkins install is contained in ./appinfo/jenkins.txt"
}


resource "local_file" "jenkins-details" {
  filename        = "./appinfo/jenkins.txt"
  content         = <<-EOT
  URL: http://${module.jenkins_server.external_ip[0]}:8080
  Admin login details: ${module.jenkins_server.jenkins_admin_login}
  Builder login details: ${module.jenkins_server.jenkins_builder_login}
  EOT
  file_permission = "0600"
}



# Produce a file containing the Backstage url and access details

output "backstage_message" {
  value = "Information on your Backstage install is contained in ./appinfo/backstage.txt"
}


resource "local_file" "backstage-details" {
  filename        = "./appinfo/backstage.txt"
  content         = <<-EOT
  # URL: http://${module.backstage_server.external_ip[0]}:3000
  Admin login details: ${module.backstage_server.backstage_admin_login}
  EOT
  file_permission = "0600"
}



# Produce a file containing the ssh key for later use with ssh -i

locals {
  ssh_key = <<-EOT
    ${openstack_compute_keypair_v2.keypair.private_key}
  EOT
}


resource "local_file" "output-ssh-key" {
  filename        = "./${var.build_project}.ssh"
  content         = local.ssh_key
  file_permission = "0600"
}


output "ssh_message" {
  value = "Your ssh key to access ${var.build_project} machines via ssh is contained in ${var.build_project}.ssh. Usage: ssh -i ${var.build_project}.ssh <user>@<host>"
}