terraform {
  required_version = ">= 1.6"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

# Authenticates as the Sunbeam admin user in admin_domain.
# Source the openrc produced by `sunbeam openrc > admin_openrc` before running.
provider "openstack" {}

# S3 API on Ceph RGW, used only for state buckets (the OpenStack provider can't
# set bucket policies, versioning or public-access blocks).
# Credentials: the admin's EC2 pair in AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   openstack ec2 credentials create
# Also export, for RGW compatibility with the AWS SDK's default checksums:
#   AWS_REQUEST_CHECKSUM_CALCULATION=when_required
#   AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
provider "aws" {
  region                      = var.region
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3 = var.s3_endpoint
  }
}
