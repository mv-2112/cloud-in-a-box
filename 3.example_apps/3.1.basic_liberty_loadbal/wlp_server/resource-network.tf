

resource "openstack_networking_floatingip_v2" "wlp-floatip_1" {
  count = var.expose == false ? 0 : var.number_to_build
  pool  = data.openstack_networking_network_v2.external_network.name
}


resource "openstack_compute_floatingip_associate_v2" "wlp-floatip-ass_1" {
  count       = var.expose == false ? 0 : var.number_to_build
  floating_ip = openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address
  instance_id = openstack_compute_instance_v2.wlp-instance[count.index].id
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
  count       = var.expose == false ? 0 : var.number_to_build
  zone_id     = data.openstack_dns_zone_v2.this-domain.id
  name        = "${openstack_compute_instance_v2.wlp-instance[count.index].name}-external.${var.project}.${var.domain}."
  description = "Wlp Server"
  ttl         = 3000
  type        = "A"
  records     = [openstack_networking_floatingip_v2.wlp-floatip_1[count.index].address]
}


# Create loadbalancer
resource "openstack_lb_loadbalancer_v2" "wlp-lb" {
  name          = "${var.project}.${var.domain}-lb"
  vip_subnet_id = data.openstack_networking_subnet_v2.wlp_network.id
}


# Create listener
resource "openstack_lb_listener_v2" "wlp-http-lb-listener" {
  name            = "${var.project}.${var.domain}-http-lb-listener"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.wlp-lb.id
  #depends_on      = [openstack_lb_loadbalancer_v2.http]

  # insert_headers = {
  #   X-Forwarded-For = "true"
  #   X-Forwarded-Proto = "true"
  # }
}


# # Create listener
# resource "openstack_lb_listener_v2" "wlp-https-lb-listener" {
#   name            = "${var.project}.${var.domain}-https-lb-listener"
#   protocol        = "TCP"
#   protocol_port   = 443
#   loadbalancer_id = openstack_lb_loadbalancer_v2.wlp-lb.id
#   #depends_on      = [openstack_lb_loadbalancer_v2.http]

#   insert_headers = {
#     X-Forwarded-For = "true"
#     X-Forwarded-Proto = "true"
#   }
# }

# Create pool
resource "openstack_lb_pool_v2" "wlp-lb-pool" {
  name        = "${var.project}.${var.domain}-lb-pool"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.wlp-http-lb-listener.id
  #depends_on  = [openstack_lb_listener_v2.http]
}


# Add member to pool
resource "openstack_lb_member_v2" "wlp-lb-pool-members" {
  count         = var.number_to_build
  name          = openstack_compute_instance_v2.wlp-instance[count.index].name
  address       = openstack_compute_instance_v2.wlp-instance[count.index].access_ip_v4
  protocol_port = 9080
  pool_id       = openstack_lb_pool_v2.wlp-lb-pool.id
  subnet_id     = data.openstack_networking_subnet_v2.wlp_network.id
  #depends_on    = [openstack_lb_pool_v2.http]
}


resource "openstack_lb_monitor_v2" "wlp-lb-monitor" {
  name           = "${var.project}.${var.domain}-lb-monitor"
  pool_id        = openstack_lb_pool_v2.wlp-lb-pool.id
  type           = "HTTP"
  http_method    = "GET"
  url_path       = "/"
  delay          = 20
  timeout        = 10
  max_retries    = 5
  expected_codes = "200"
}


# Get floating IP
resource "openstack_networking_floatingip_v2" "floatingip_1" {
  pool = data.openstack_networking_network_v2.external_network.name
}


# Associate floating IP to LoadBalancer
resource "openstack_networking_floatingip_associate_v2" "floatip_1" {
  floating_ip = openstack_networking_floatingip_v2.floatingip_1.address
  port_id     = openstack_lb_loadbalancer_v2.wlp-lb.vip_port_id
}


output "LoadBalancer_IP" {
  value = "http://${openstack_networking_floatingip_v2.floatingip_1.address}"
}
