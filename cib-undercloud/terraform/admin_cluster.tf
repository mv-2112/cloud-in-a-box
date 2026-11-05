# Platform Kubernetes cluster in the admin project.
#
# Hosts platform services, deployed by the second stage in ../platform:
#   - the platform GitHub Actions runners (ARC), serving only cib-tenants
#   - Backstage, with its CloudNativePG database
#   - Traefik, cert-manager, CloudNativePG operator, Cinder StorageClasses
#
# Only the cluster is created here: Terraform can't configure the helm and
# kubernetes providers from a cluster created in the same run.

locals {
  admin_cluster_k8s_version = try(coalesce(var.admin_cluster.kubernetes_version), sort(keys(var.k8s_templates))[0])
}

module "admin_cluster" {
  source = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/k8s-cluster?ref=v1.1.1"
  count  = var.admin_cluster != null ? 1 : 0

  name               = "cib-platform"
  kubernetes_version = local.admin_cluster_k8s_version
  master_count       = var.admin_cluster.master_count
  node_count         = var.admin_cluster.node_count

  # The template is created in this same configuration.
  depends_on = [openstack_containerinfra_clustertemplate_v1.k8s]
}

output "admin_cluster_name" {
  value = var.admin_cluster != null ? module.admin_cluster[0].cluster_name : null
}
