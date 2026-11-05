# A fixed address for the admin cluster's ingress (Traefik).
#
# Left to itself, the OpenStack cloud controller gives Traefik's load
# balancer a random floating IP, and a new one each time the load balancer
# or cluster is rebuilt, so DNS can't point at it. This reserves one address
# up front, in the admin project (the cluster's), and the platform stage
# hands it to Traefik (spec.loadBalancerIP). The cloud controller then
# attaches this floating IP and leaves it in place when the Service goes.
#
# The address sits outside the floating IP pool (EXT_RANGE): Neutron only
# hands out pool addresses by itself, so nothing else can take it. Name it
# in the router's DNS (HomeLab RB4011_v4 src/lablan/34-dns.rsc).
resource "openstack_networking_floatingip_v2" "platform_ingress" {
  count = var.admin_cluster != null && var.platform_ingress_ip != null ? 1 : 0

  pool        = openstack_networking_network_v2.external.name
  subnet_id   = openstack_networking_subnet_v2.external.id
  address     = var.platform_ingress_ip
  description = "cib-platform ingress (Traefik); DNS points here"
}

output "platform_ingress_ip" {
  description = "The admin cluster's ingress address (null = not fixed; see the platform stage's ingress_ip output)."
  value       = one(openstack_networking_floatingip_v2.platform_ingress[*].address)
}

output "cloud_name" {
  value = var.cloud_name
}
