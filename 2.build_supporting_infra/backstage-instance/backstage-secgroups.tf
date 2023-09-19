resource "openstack_networking_secgroup_v2" "backstage-secgroup" {
  name        = "${var.project}-backstage-secgroup"
  description = "${var.project} backstage security group"
}

resource "openstack_networking_secgroup_rule_v2" "backstage-secgroup_rule" {
  count = length(var.tcp_ports)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = "${var.tcp_ports[count.index]}"
  port_range_max    = "${var.tcp_ports[count.index]}"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.backstage-secgroup.id}"
}
