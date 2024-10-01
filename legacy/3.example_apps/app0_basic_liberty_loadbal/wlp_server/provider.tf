# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

# Configure the OpenStack Provider
#provider "openstack" {
  # use_octavia   = true
#}
