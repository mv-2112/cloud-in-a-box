terraform {
  required_providers {
    # helm provider 3.x is the current line (there is no 4.x yet) and embeds
    # the Helm v3 SDK. Helm 4 still installs apiVersion v2 charts, so a Helm 4
    # based provider should be a version bump here, not a module rewrite.
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
