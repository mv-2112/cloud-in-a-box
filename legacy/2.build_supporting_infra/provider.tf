# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
    # github = {
    #   source = "integrations/github"
    #   version = "6.0.0"
    # }
  }
}
