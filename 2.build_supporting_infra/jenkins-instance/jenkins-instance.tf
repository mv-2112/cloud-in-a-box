resource "random_password" "jenkins_password" {
  length = 16
  special = false
}


resource "openstack_blockstorage_volume_v3" "jenkins-datavol" {
  name = "jenkins-datavol"
  size = 10
}


resource "openstack_compute_instance_v2" "jenkins-instance" {
  name            = "${var.project}-jenkins"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavour}"
  key_pair        = "${var.project}-keypair"
  security_groups = ["${var.project}-jenkins-secgroup"]
  #security_groups = ["${var.project}-jenkins-secgroup", "${openstack_networking_secgroup_v2.jenkins-secgroup.id}"]

  user_data = templatefile("${path.module}/jenkins.userdata", { project = var.project, domain = var.domain, JENKINS_PASSWORD = random_password.jenkins_password.result, JENKINS_ADDRESS = "0.0.0.0" })

  network {
    name = "${var.project}-${var.domain}-network"
  }
}


# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = "${openstack_compute_instance_v2.jenkins-instance.id}"
#   volume_id   = "${openstack_blockstorage_volume_v3.jenkins-datavol.id}"
# }