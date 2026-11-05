terraform {
  required_version = ">= 1.9"

  # Same platform bucket as stage 1, different key. Endpoint via
  # -backend-config='endpoints={s3="..."}'; admin EC2 creds in AWS_*.
  backend "s3" {
    bucket                      = "cib-undercloud-tfstate"
    key                         = "platform/terraform.tfstate"
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
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.3, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
  }
}

# Sunbeam admin, as for stage 1.
provider "openstack" {}
