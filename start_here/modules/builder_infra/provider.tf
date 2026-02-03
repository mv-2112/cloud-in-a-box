# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }
  }
}


provider "helm" {
  alias = "helm_config"
  kubernetes {
    config_path = "${path.cwd}/config/${openstack_containerinfra_cluster_v1.cluster_1.name}/config"
  }
}



provider "kubernetes" {
  alias       = "kubernetes_config"
  config_path = "${path.cwd}/config/${openstack_containerinfra_cluster_v1.cluster_1.name}/config"
  # For now comment this out until magnum config is fixed for CAPI
  # config_context = "${openstack_containerinfra_cluster_v1.cluster_1.name}"
}
