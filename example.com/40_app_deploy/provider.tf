# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.34.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.16.1"
    }
  }
}




provider "helm" {
  kubernetes {
    config_path = "../config/${var.k8s_cluster}/config"
  }

#   # localhost registry with password protection
#   registry {
#     url = "oci://localhost:5000"
#     username = "username"
#     password = "password"
#   }

#   # private registry
#   registry {
#     url = "oci://private.registry"
#     username = "username"
#     password = "password"
#   }
}



provider "kubernetes" {
  config_path = "../config/${var.k8s_cluster}/config"
  config_context = var.k8s_cluster
}