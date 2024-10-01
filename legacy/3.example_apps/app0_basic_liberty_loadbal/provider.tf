# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  # user_name   = "builder-admin"
  tenant_name = "app0"
  # use_octavia   = true
}


terraform {
  backend "s3" {
    bucket = "app0-bucket-1"
    key    = "terraform/terraform.tfstate"
    region = "RegionOne"
    endpoints = {
      s3 = "http://10.20.21.12"

    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

