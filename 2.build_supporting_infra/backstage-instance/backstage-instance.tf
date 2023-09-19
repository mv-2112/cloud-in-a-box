resource "random_password" "backstage_password" {
  length = 16
  special = false
}


# resource "openstack_blockstorage_volume_v3" "backstage-datavol" {
#   name = "backstage-datavol"
#   size = 10
# }


resource "openstack_compute_instance_v2" "backstage-instance" {
  name            = "${var.project}-backstage"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavour}"
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-backstage-secgroup"]
  #security_groups = ["${var.project}-backstage-secgroup", "${openstack_networking_secgroup_v2.backstage-secgroup.id}"]

  user_data = templatefile("${path.module}/backstage.userdata", { project = var.project, domain = var.domain, BACKSTAGE_PASSWORD = random_password.backstage_password.result, FLOAT_IP = openstack_networking_floatingip_v2.backstage-floatip_1.address })

  network {
    name = "${var.project}-${var.domain}-network"
    # name = "external-network"

  }
}


# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = "${openstack_compute_instance_v2.backstage-instance.id}"
#   volume_id   = "${openstack_blockstorage_volume_v3.backstage-datavol.id}"
# }