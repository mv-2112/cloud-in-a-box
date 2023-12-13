resource "openstack_compute_instance_v2" "wlp-instance" {
  count = var.number_to_build
  name            = "${var.project}-wlp-${count.index}"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavour}"
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-wlp-secgroup"]

  user_data = "${file("${path.module}/wlp.userdata")}"

  network {
    name = "${var.project}-${var.domain}-network"
  }

  # lifecycle {
  #   create_before_destroy = true
  # }

}
