

resource "openstack_networking_floatingip_v2" "wlp-floatip_1" {
  count = var.expose_node == false ? 0 : var.number_to_build
  pool  = data.openstack_networking_network_v2.external_network.name
}


resource "openstack_networking_floatingip_associate_v2" "wlp-floatip-ass_1" {
  count       = var.expose_node == false ? 0 : var.number_to_build
  floating_ip = openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address
  # instance_id = openstack_compute_instance_v2.wlp-instance[count.index].id
  port_id = openstack_compute_instance_v2.wlp-instance[count.index].network.port
}


resource "openstack_dns_recordset_v2" "wlp-dns-1" {
  count       = var.number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.wlp-instance[count.index].name}.${var.project}.${var.domain}."
  description = "Wlp Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_compute_instance_v2.wlp-instance[count.index].access_ip_v4]
}


resource "openstack_dns_recordset_v2" "wlp-dns-2" {
  count       = var.expose_node == false ? 0 : var.number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.wlp-instance[count.index].name}-external.${var.project}.${var.domain}."
  description = "Wlp Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address]
}



# Load balancer

# Amphora LB
















# OVN LB

# Create loadbalancer
resource "openstack_lb_loadbalancer_v2" "wlp-lb" {
  count                 = var.expose_lb == false ? 0 : 1
  name                  = "${var.project}.${var.domain}-lb"
  vip_subnet_id         = data.openstack_networking_subnet_v2.wlp_network.id
  loadbalancer_provider = "ovn"
}


# Create listener
resource "openstack_lb_listener_v2" "wlp-http-lb-listener" {
  count           = var.expose_lb == false ? 0 : 1
  name            = "${var.project}.${var.domain}-http-lb-listener"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.wlp-lb[0].id
}


# Create listener
resource "openstack_lb_listener_v2" "wlp-https-lb-listener" {
  count           = var.expose_lb == false ? 0 : 1
  name            = "${var.project}.${var.domain}-https-lb-listener"
  protocol        = "TCP"
  protocol_port   = 443
  loadbalancer_id = openstack_lb_loadbalancer_v2.wlp-lb[0].id
}

# Create pool
resource "openstack_lb_pool_v2" "wlp-lb-pool" {
  count = var.expose_lb == false ? 0 : 1
  name  = "${var.project}.${var.domain}-lb-pool"

  # Amphora
  #protocol    = "TCP"
  #lb_method   = "ROUND_ROBIN"
  #listener_id = openstack_lb_listener_v2.wlp-http-lb-listener.id

  # OVN
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.wlp-http-lb-listener[0].id

}


# Add member to pool
resource "openstack_lb_member_v2" "wlp-lb-pool-members" {
  count         = var.expose_lb == false ? 0 : var.number_to_build
  name          = openstack_compute_instance_v2.wlp-instance[count.index].name
  address       = openstack_compute_instance_v2.wlp-instance[count.index].access_ip_v4
  protocol_port = 9080
  pool_id       = openstack_lb_pool_v2.wlp-lb-pool[0].id
  subnet_id     = data.openstack_networking_subnet_v2.wlp_network.id
  #depends_on    = [openstack_lb_pool_v2.http]
}


# OVN monitor
resource "openstack_lb_monitor_v2" "wlp-lb-monitor" {
  count            = var.expose_lb == false ? 0 : 1
  name             = "${var.project}.${var.domain}-lb-monitor"
  pool_id          = openstack_lb_pool_v2.wlp-lb-pool[0].id
  type             = "TCP"
  delay            = 5
  timeout          = 5
  max_retries      = 3
  max_retries_down = 3
}

# Amphora Monitor
# resource "openstack_lb_monitor_v2" "wlp-lb-monitor" {
#   name           = "${var.project}.${var.domain}-lb-monitor"
#   pool_id        = openstack_lb_pool_v2.wlp-lb-pool.id
#   type           = "HTTP"
#   http_method    = "GET"
#   url_path       = "/"
#   delay          = 20
#   timeout        = 10
#   max_retries    = 5
#   expected_codes = "200"
# }





# Get floating IP
resource "openstack_networking_floatingip_v2" "lb_floatingip_1" {
  count = var.expose_lb == false ? 0 : 1
  pool  = data.openstack_networking_network_v2.external_network.name
}


# Associate floating IP to LoadBalancer
resource "openstack_networking_floatingip_associate_v2" "lb_floatingip_1" {
  count       = var.expose_lb == false ? 0 : 1
  floating_ip = openstack_networking_floatingip_v2.lb_floatingip_1[0].address
  port_id     = openstack_lb_loadbalancer_v2.wlp-lb[0].vip_port_id
}
