# Define required providers
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Configure the Global GitHub Provider - where the modules go
provider "github" {
  token = var.github_token
  owner = var.github_organization
}
