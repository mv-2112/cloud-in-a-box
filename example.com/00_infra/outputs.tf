locals {
  ssh_key = <<-EOT
    ${openstack_compute_keypair_v2.keypair.private_key}
  EOT
  cluster_vars = <<-EOT
    variable "k8s_cluster" {
      type    = string
      default = ${openstack_containerinfra_cluster_v1.cluster_1.name}
    }
  EOT
}


resource "local_file" "output-ssh-key" {
  filename        = "./builder.ssh"
  content         = local.ssh_key
  file_permission = "0600"
}


output "ssh_message" {
  value = "Your ssh key to access ${var.domain} builder machines via ssh is contained in builder.ssh. Usage: ssh -i builder.ssh <user>@<host>"
}

output "k8s_message" {
  value = "Your Kubernetes cluster ${openstack_containerinfra_cluster_v1.cluster_1.name} has been created, its kubeconfig is at ${local_sensitive_file.builder_k8s_config.filename}."
}