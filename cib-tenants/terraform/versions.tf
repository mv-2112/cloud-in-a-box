terraform {
  required_version = ">= 1.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Container created by cib-undercloud. Endpoint + credentials are supplied by
  # the pipeline: -backend-config='endpoints={s3="..."}' and AWS_* env vars.
  backend "s3" {
    bucket                      = "cib-tenants-tfstate"
    key                         = "tenants/terraform.tfstate"
    region                      = "RegionOne"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

# Admin credentials (ideally an application credential) from OS_* env vars.
provider "openstack" {}

# One GitHub org for all tenant repos; token from GITHUB_TOKEN.
# Terraform can't for_each over providers, so tenants that need their repo in a
# different org need either a second root module or OpenTofu >= 1.9 provider for_each.
provider "github" {
  owner = var.github_owner
}

# S3 API on Ceph RGW for per-tenant state buckets, as the platform admin.
# Uses the same admin EC2 pair as the backend (AWS_* env vars).
provider "aws" {
  region                      = "RegionOne"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3 = var.s3_endpoint
  }
}
