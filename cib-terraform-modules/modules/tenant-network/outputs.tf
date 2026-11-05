output "network_id" {
  value = openstack_networking_network_v2.network.id
}

output "network_name" {
  value = openstack_networking_network_v2.network.name
}

output "subnet_ids" {
  value = { for k, v in openstack_networking_subnet_v2.subnet : k => v.id }
}

output "router_id" {
  value = openstack_networking_router_v2.router.id
}

output "keypair_name" {
  value = var.create_keypair ? openstack_compute_keypair_v2.keypair[0].name : null
}

output "private_key" {
  value     = var.create_keypair && var.public_key == null ? openstack_compute_keypair_v2.keypair[0].private_key : null
  sensitive = true
}

output "ipv6_cidr" {
  description = "The network's routed IPv6 /64, or null."
  value       = var.ipv6_enabled ? openstack_networking_subnet_v2.ipv6[0].cidr : null
}
