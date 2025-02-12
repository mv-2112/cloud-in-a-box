data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

resource "random_string" "suffix" {
  length   = 5
  special  = false
  lower    = true
  upper    = false
}


resource "openstack_compute_keypair_v2" "keypair" {
  name = "builder-keypair"
}


resource "openstack_containerinfra_cluster_v1" "cluster_1" {
  name                = "builder-cluster-${random_string.suffix.result}"
  cluster_template_id = var.cluster_template
  master_count        = 1
  node_count          = 1
  keypair             = openstack_compute_keypair_v2.keypair.id
  create_timeout      = 1440
  # added as when creating with terraform gets ignored from template
  # floating_ip_enabled = true
}




