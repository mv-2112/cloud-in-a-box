locals {
  chart_url = "https://charts.jetstack.io"
}

resource "helm_release" "cert-manager" {
  repository       = local.chart_url
  chart            = "cert-manager"
  name             = "cert-manager"
  namespace        = "cert-manager"
  version          = var.cert_manager_version
  create_namespace = true
  set {
    name  = "crds.enabled"
    value = "true"
  }
}

