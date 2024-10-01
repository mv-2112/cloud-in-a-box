resource "random_password" "password" {
  length  = 16
  special = false
}

data "openstack_networking_network_v2" "external_network" {
  name = "external-network"
}

# Get the builder-example.com-network network and its subnet
data "openstack_networking_network_v2" "build_network" {
  name = "${var.build_project}-${var.domain}-network"
}

data "openstack_networking_subnet_v2" "build_subnet" {
  subnet_id = data.openstack_networking_network_v2.build_network.subnets[0]
}





module "jenkins_server" {
  source         = "./jenkins-instance"
  project        = var.build_project
  image          = "ubuntu"
  flavour        = "m1.medium"
  domain         = var.domain
  lb_floating_ip = openstack_networking_floatingip_v2.build-lb-floatingip-1.address
}

module "backstage_server" {
  source                    = "./backstage-instance"
  project                   = var.build_project
  image                     = "ubuntu"
  flavour                   = "m1.medium"
  domain                    = var.domain
  lb_floating_ip            = openstack_networking_floatingip_v2.build-lb-floatingip-1.address
  github_pat                = var.github_pat
  auth_github_client_id     = var.auth_github_client_id
  auth_github_client_secret = var.auth_github_client_secret
}


resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.build_project}-keypair"
}


# resource "github_repository" "example" {
#   name        = "guff"
#   description = "My awesome codebase"
# }
