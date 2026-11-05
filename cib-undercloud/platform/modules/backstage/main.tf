# Backstage for the platform, using the image built from
# https://github.com/mv-2112/Backstage-Testbed (app-config baked in).
#
# Needs in the cluster: CloudNativePG operator, cert-manager, an ingress
# controller (Traefik) and a StorageClass. platform-addons provides all four.

terraform {
  required_providers {
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

resource "kubernetes_namespace_v1" "backstage" {
  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# GitHub App credentials (sign-in, catalog ingestion, scaffolder). Kept out of
# git; previously backstage-secrets.yaml.
resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = "backstage-github-secrets"
    namespace = kubernetes_namespace_v1.backstage.metadata[0].name
  }

  data = {
    GITHUB_APP_ID            = var.github_app.app_id
    GITHUB_APP_CLIENT_ID     = var.github_app.client_id
    GITHUB_APP_CLIENT_SECRET = var.github_app.client_secret
    GITHUB_APP_PRIVATE_KEY   = var.github_app.private_key
  }
}

resource "helm_release" "backstage" {
  name      = "backstage"
  namespace = kubernetes_namespace_v1.backstage.metadata[0].name
  chart     = "${path.module}/chart"

  # The database and certificate take a while on first install.
  timeout = 900

  values = [yamlencode({
    image            = var.image
    hostname         = var.hostname
    replicas         = var.replicas
    githubSecretName = kubernetes_secret_v1.github.metadata[0].name
    ingressClassName = var.ingress_class
    ingressNamespace = var.ingress_namespace
    cnpgNamespace    = var.cnpg_namespace
    tls = {
      clusterIssuer          = var.cluster_issuer
      createSelfSignedIssuer = var.create_self_signed_issuer
    }
    database = {
      instances    = var.database_instances
      size         = var.database_size
      storageClass = var.storage_class
    }
  })]
}
