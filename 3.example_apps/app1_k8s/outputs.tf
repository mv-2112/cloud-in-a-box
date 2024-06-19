# output "pub_keypair" {
#   value = openstack_compute_keypair_v2.keypair.public_key
# }

# output "priv_keypair" {
#   value = openstack_compute_keypair_v2.keypair.private_key
#   sensitive = true
# }


# locals {
#   ssh_key = <<-EOT
#     ${openstack_compute_keypair_v2.keypair.private_key}
#   EOT
# }

# resource "local_file" "output-ssh-key" {
#   filename = "./${var.app_project}.ssh"
#   content  = local.ssh_key
#   file_permission = "0600"
# }



# Produce a file containing the app1 url and access details

output "app1_message" {
  value = "Information on your app1 install is contained in ${var.app_project}.txt"
}


resource "local_file" "app1-details" {
  filename = "./appinfo/app1.txt"
  content  = <<-EOT
  mkdir config-dir
  openstack coe cluster config app1-k8s-cluster --dir config-dir/
  export KUBECONFIG=$(pwd)/config-dir/config
  kubectl --kubeconfig $KUBECONFIG get pods -A
  EOT
  file_permission = "0600"
}