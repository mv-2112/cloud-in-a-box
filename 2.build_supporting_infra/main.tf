resource "random_password" "password" {
  length = 16
  special = false
}

data "openstack_networking_network_v2" "external_network" {
  name = "external-network"
}

module "jenkins_server" {
  source = "./jenkins-instance"

  project = var.build_project
  image   = "ubuntu"
  flavour = "m1.medium"
  domain  = var.domain
  expose  = true
}

module "backstage_server" {
  source = "./backstage-instance"

  project = var.build_project
  image   = "ubuntu"
  flavour = "m1.large"
  domain  = var.domain
  expose  = true
}

resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.build_project}-keypair"
}