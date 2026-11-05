# The "catalogue": what the undercloud publishes for the other repos.
# cib-tenants reads this with terraform_remote_state; the modules repo only
# relies on the naming conventions, so it has no hard dependency on this state.

output "cluster_templates" {
  description = "Kubernetes version => Magnum cluster template name"
  value       = { for k, v in openstack_containerinfra_clustertemplate_v1.k8s : k => v.name }
}

output "images" {
  value = merge(
    { for k, v in openstack_images_image_v2.base : k => v.id },
    { for k, v in openstack_images_image_v2.magnum_capi_image : v.name => v.id },
  )
}

output "shared_security_groups" {
  description = "Short name => security group ID (share into tenant projects with Neutron RBAC)"
  value       = { for k, v in openstack_networking_secgroup_v2.shared : k => v.id }
}

output "external_network_id" {
  value = openstack_networking_network_v2.external.id
}

output "volume_types" {
  value = [
    openstack_blockstorage_volume_type_v3.standard.name,
    openstack_blockstorage_volume_type_v3.multiattach.name,
  ]
}

output "tenants_state_bucket" {
  value = module.state_bucket["cib-tenants-tfstate"].bucket
}

# cib-tenants needs these to build per-tenant buckets the same way.
output "s3_endpoint" {
  value = var.s3_endpoint
}

output "rgw_project_namespacing" {
  value = var.rgw_project_namespacing
}

output "cloud_ca_cert_pem" {
  description = "Handed to cib-tenants for tenant runners."
  value       = var.cloud_ca_cert_pem
}

output "ipv6" {
  description = "VM-side IPv6: external /64 and the default tenant subnet pool (null when IPv6 is off)."
  value = {
    external_cidr      = var.external_network_config.ipv6_cidr
    tenant_pool        = var.tenant_ipv6_pool
    tenant_subnetpool  = local.tenant_ipv6_enabled ? openstack_networking_subnetpool_v2.tenant_v6[0].name : null
    management_version = var.management_ip_version
  }
}
