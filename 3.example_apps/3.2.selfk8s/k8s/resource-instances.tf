resource "openstack_compute_instance_v2" "gke-master" {
  count = var.gke_master_number_to_build
  name            = "${var.project}-gke-master-${count.index}"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavour}"
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-gke-secgroup"]

  user_data = "${file("${path.module}/gke-master.userdata")}"

  network {
    name = "${var.project}-${var.domain}-network"
  }
}

resource "openstack_compute_instance_v2" "gke-node" {
  count = var.gke_node_number_to_build
  name            = "${var.project}-gke-node-${count.index}"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavour}"
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-gke-secgroup"]

  user_data = "${file("${path.module}/gke-node.userdata")}"

  network {
    name = "${var.project}-${var.domain}-network"
  }
}
