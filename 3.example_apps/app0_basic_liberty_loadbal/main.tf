# Setup our Websphere Liberty

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}


resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.app_project}-keypair"
}



# resource "openstack_objectstorage_container_v1" "container_1" {
#   region = "RegionOne"
#   name   = "${var.app_project}-bucket-1"
# }



#resource "openstack_objectstorage_object_v1" "doc_1" {
#  region         = "RegionOne"
#  container_name = "${openstack_objectstorage_container_v1.container_1.name}"
#  name           = "test/default.json"
#
#  content_type = "application/json"
#  source       = "./default.json"
#}



module "wlp_server" {
  source = "./wlp_server"

  project          = var.app_project
  image            = var.default_image
  flavour          = "m1.medium"
  number_to_build  = 2
  expose_node      = false
  expose_lb        = true
  domain           = var.domain
  external_network = var.external_network
}



# module "db_server" {
#   source = "./modules/chef_server"
#   #version = "0.1.0"

#   project = "${var.app_project}"
#   image   = "impish-server"
#   flavour = "g1.medium"

#   depends_on = [ openstack_networking_router_v2.router_1 ]
# }
