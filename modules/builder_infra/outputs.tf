locals {
  ssh_key      = <<-EOT
    ${openstack_compute_keypair_v2.keypair.private_key}
  EOT
  cluster_vars = <<-EOT
    variable "k8s_cluster" {
      type    = string
      default = ${openstack_containerinfra_cluster_v1.cluster_1.name}
    }
  EOT
}


resource "local_sensitive_file" "output-ssh-key" {
  filename        = "${path.cwd}/config/ssh/builder.ssh"
  content         = local.ssh_key
  file_permission = "0600"
}

resource "local_sensitive_file" "builder_k8s_config" {
  filename        = "${path.cwd}/config/${openstack_containerinfra_cluster_v1.cluster_1.name}/config"
  content         = openstack_containerinfra_cluster_v1.cluster_1.kubeconfig.raw_config
  file_permission = "0600"
}

resource "local_sensitive_file" "env_file" {
  filename        = "${path.cwd}/setup_env.sh"
  content = <<EOT
export KUBECONFIG=${local_sensitive_file.builder_k8s_config.filename}
. ./builder_openrc
alias buildssh="ssh -i ${local_sensitive_file.output-ssh-key.filename}"
EOT
  file_permission = "0600"
}

output "ssh_message" {
  value = "Your ssh key to access your builder machines via ssh is contained in builder.ssh. Usage: ssh -i ${local_sensitive_file.output-ssh-key.filename} <user>@<host>"
}

output "k8s_message" {
  value = "Your Kubernetes cluster ${openstack_containerinfra_cluster_v1.cluster_1.name} has been created, its kubeconfig is at ${local_sensitive_file.builder_k8s_config.filename}."
}

output "k8s_cluster_name" {
  value = openstack_containerinfra_cluster_v1.cluster_1.name
}

output "path_cwd" {
  value = path.cwd
}

output "path_module" {
  value = path.module
}

output "path_root" {
  value = path.root
}
