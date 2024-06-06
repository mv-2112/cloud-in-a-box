# Load balancer

# Amphora LB
# Not implemented yet




# OVN LB

# Create loadbalancer
resource "openstack_lb_loadbalancer_v2" "build-lb" {
  name                  = "${var.build_project}.${var.domain}-lb"
  vip_subnet_id         = data.openstack_networking_subnet_v2.build_subnet.subnet_id
  loadbalancer_provider = "ovn"
}



# Iteratively create listeners
resource "openstack_lb_listener_v2" "build-lb-listener" {
  for_each = {
    for combination in flatten([
      for application in var.build_applications : [
        for port in application.ports : {
          key         = "${application.name}-${port.description}"
          application = application
          port        = port
        }
      ]
    ]) :
    combination.key => combination
  }
  name            = "${var.build_project}.${var.domain}-${each.value.key}-lb-listener"
  protocol        = upper(each.value.port.protocol)
  protocol_port   = each.value.port.port_number
  loadbalancer_id = openstack_lb_loadbalancer_v2.build-lb.id
}



# Create pool
resource "openstack_lb_pool_v2" "build-lb-pool" {
  for_each = {
    for combination in flatten([
      for application in var.build_applications : [
        for port in application.ports : {
          key         = "${application.name}-${port.description}"
          application = application
          port        = port
        }
      ]
    ]) :
    combination.key => combination
  }
  name = "${var.build_project}.${var.domain}-${each.value.key}-lb-pool"

  # Amphora
  #protocol    = "TCP"
  #lb_method   = "ROUND_ROBIN"
  #listener_id = openstack_lb_listener_v2.build-http-lb-listener.id

  # OVN
  protocol    = upper(each.value.port.protocol)
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.build-lb-listener[each.value.key].id

}

locals {
  app_ip = {
    jenkins = {
      internal_ip = module.jenkins_server.internal_ip[0]
      external_ip = module.jenkins_server.external_ip[0]
    }
    backstage = {
      internal_ip = module.backstage_server.internal_ip[0]
      external_ip = module.backstage_server.external_ip[0]
    }
  }
}

# Add member to pool
resource "openstack_lb_member_v2" "build-lb-pool-members" {
  for_each = {
    for combination in flatten([
      for application in var.build_applications : [
        for port in application.ports : {
          key         = "${application.name}-${port.description}"
          application = application
          port        = port
        }
      ]
    ]) :
    combination.key => combination
  }
  name          = "${each.value.application.name}-instance"
  address       = local.app_ip[each.value.application.name].internal_ip
  protocol_port = each.value.port.port_number
  pool_id       = openstack_lb_pool_v2.build-lb-pool[each.value.key].id
  subnet_id     = data.openstack_networking_subnet_v2.build_subnet.id
  #depends_on    = [openstack_lb_pool_v2.http]
}


# OVN monitor
resource "openstack_lb_monitor_v2" "build-lb-monitor" {
  for_each = {
    for combination in flatten([
      for application in var.build_applications : [
        for port in application.ports : {
          key         = "${application.name}-${port.description}"
          application = application
          port        = port
        }
      ]
    ]) :
    combination.key => combination
  }
  name             = "${var.build_project}.${var.domain}-${each.value.key}-lb-monitor"
  pool_id          = openstack_lb_pool_v2.build-lb-pool[each.value.key].id
  type             = upper(each.value.port.protocol)
  delay            = 5
  timeout          = 5
  max_retries      = 3
  max_retries_down = 3
}

# Amphora Monitor
# resource "openstack_lb_monitor_v2" "build-lb-monitor" {
#   name           = "${var.build_project}.${var.domain}-lb-monitor"
#   pool_id        = openstack_lb_pool_v2.build-lb-pool.id
#   type           = "HTTP"
#   http_method    = "GET"
#   url_path       = "/"
#   delay          = 20
#   timeout        = 10
#   max_retries    = 5
#   expected_codes = "200"
# }


# Get floating IP
resource "openstack_networking_floatingip_v2" "build-lb-floatingip-1" {
  pool = data.openstack_networking_network_v2.external_network.name
}


# Associate floating IP to LoadBalancer
resource "openstack_networking_floatingip_associate_v2" "build-lb-floatingip-assoc-1" {
  floating_ip = openstack_networking_floatingip_v2.build-lb-floatingip-1.address
  port_id     = openstack_lb_loadbalancer_v2.build-lb.vip_port_id
}
