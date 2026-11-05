# Stage 1: network + Kubernetes cluster in this tenant's builder project.
# Module sources point at your org: set by ./set-org.py at the top level.

terraform {
  required_version = ">= 1.9"

  # Partial config: bucket/endpoint/credentials come from -backend-config and
  # the AWS_* env vars set by the pipeline (see .github/workflows/deploy.yaml).
  backend "s3" {
    key                         = "infra/terraform.tfstate"
    region                      = "RegionOne"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# Credentials come from OS_* environment variables.
provider "openstack" {}

module "network" {
  source       = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/tenant-network?ref=v1.1.1"
  name_prefix  = var.domain
  ipv6_enabled = var.enable_ipv6
}

module "cluster" {
  source             = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/k8s-cluster?ref=v1.1.1"
  count              = var.enable_cluster ? 1 : 0
  kubernetes_version = var.kubernetes_version
  keypair_name       = module.network.keypair_name
  node_count         = var.node_count
}

output "cluster_name" {
  value = var.enable_cluster ? module.cluster[0].cluster_name : null
}

output "network_name" {
  value = module.network.network_name
}
