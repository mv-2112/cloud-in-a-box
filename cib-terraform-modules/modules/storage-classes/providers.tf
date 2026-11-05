terraform {
  required_version = ">= 1.9" # cross-variable validation

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
  }
}
