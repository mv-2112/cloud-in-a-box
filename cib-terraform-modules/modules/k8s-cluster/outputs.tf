output "cluster_name" {
  value = openstack_containerinfra_cluster_v1.cluster.name
}

output "cluster_id" {
  value = openstack_containerinfra_cluster_v1.cluster.id
}

output "api_address" {
  value = openstack_containerinfra_cluster_v1.cluster.api_address
}

output "kubeconfig_path" {
  description = "Path the kubeconfig is (or, with clusterctl, will be) written to. Feed this to the addons stage."
  value       = local.kubeconfig_path
}

output "kubeconfig" {
  value     = openstack_containerinfra_cluster_v1.cluster.kubeconfig
  sensitive = true
}
