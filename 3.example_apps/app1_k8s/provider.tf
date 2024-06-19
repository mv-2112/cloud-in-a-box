# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  # user_name   = "builder-admin"
  tenant_name = "app1"
  # use_octavia   = true
}
