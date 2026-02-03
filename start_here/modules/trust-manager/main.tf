locals {
  chart_url = "https://charts.jetstack.io"
}

resource "helm_release" "trust-manager" {
  repository       = local.chart_url
  chart            = "trust-manager"
  name             = "trust-manager"
  namespace        = "cert-manager"
  version          = var.trust_manager_version
  create_namespace = true
  set {
    name  = "crds.enabled"
    value = "true"
  }
}

