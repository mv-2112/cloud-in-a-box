resource "local_sensitive_file" "builder_k8s_config" {
  filename        = "../config/${openstack_containerinfra_cluster_v1.cluster_1.name}/config"
  content         = openstack_containerinfra_cluster_v1.cluster_1.kubeconfig.raw_config
  file_permission = "0600"
}