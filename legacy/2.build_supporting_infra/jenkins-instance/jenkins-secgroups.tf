resource "openstack_networking_secgroup_v2" "jenkins-secgroup" {
  name        = "${var.project}-jenkins-secgroup"
  description = "${var.project} jenkins security group"
}

resource "openstack_networking_secgroup_rule_v2" "default-secgroup_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.jenkins-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "default-secgroup_rule_2" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.jenkins-secgroup.id}"
}