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
  }
}



provider "kubernetes" {
  config_path = "~/cloud-in-a-box/example.com/config/builder-cluster-ljlac/config"
  config_context = "builder-cluster-ljlac"
}
