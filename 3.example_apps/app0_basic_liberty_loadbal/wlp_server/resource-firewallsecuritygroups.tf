resource "openstack_networking_secgroup_v2" "wlp-secgroup" {
  name        = "${var.project}-wlp-secgroup"
  description = "${var.project} wlp security group"
}

resource "openstack_networking_secgroup_rule_v2" "default-secgroup_rule_1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9080
  port_range_max    = 9080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.wlp-secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "default-secgroup_rule_2" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9443
  port_range_max    = 9443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.wlp-secgroup.id}"
}
