locals {
  istio_charts_url = "https://istio-release.storage.googleapis.com/charts"
}


resource "helm_release" "istio-base" {
  repository       = local.istio_charts_url
  chart            = "base"
  name             = "istio-base"
  namespace        = "istio-system"
  version          = var.istio_version
  create_namespace = true

  set {
    name  = "defaultRevision"
    value = "default"
  }
}


resource "helm_release" "istio-controlplane" {
  repository       = local.istio_charts_url
  chart            = "istiod"
  name             = "istiod"
  namespace        = "istio-system"
  version          = var.istio_version
  create_namespace = true
}


# resource "helm_release" "istio-cniagent" {
#   repository       = local.istio_charts_url
#   chart            = "cni"
#   name             = "istio-cni"
#   namespace        = "istio-system"
#   version          = var.istio_version
#   create_namespace = true
# }


resource "helm_release" "istio-ingress" {
  repository       = local.istio_charts_url
  chart            = "gateway"
  name             = "istio-ingress"
  namespace        = "istio-ingress"
  version          = var.istio_version
  create_namespace = true
}


# resource "helm_release" "istio-egress" {
#   repository       = local.istio_charts_url
#   chart            = "gateway"
#   name             = "istio-egress"
#   namespace        = "istio-egress"
#   version          = var.istio_version
#   create_namespace = true
# }
