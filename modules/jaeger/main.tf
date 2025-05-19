locals {
  chart_url = "https://jaegertracing.github.io/helm-charts"
  namespace = "observability"
}


resource "helm_release" "jaeger" {
  repository = local.chart_url
  chart      = "jaeger"
  name       = "jaeger"
  namespace  = local.namespace
  # version          = var.jaeger_version
  create_namespace = true
  values = [
    file("${path.module}/jaeger.yaml"),                             # Path to the values file containing configuration settings
  ]
}






# resource "helm_release" "jaeger-operator" {
#   repository       = local.chart_url
#   chart            = "jaeger-operator"
#   name             = "jaeger-operator"
#   namespace        = local.namespace
#   # version          = var.jaeger_version
#   create_namespace = true
#   # set {
#   #   name  = "crds.enabled"
#   #   value = "true"
#   # }
# }

# apiVersion: jaegertracing.io/v1
# kind: Jaeger
# metadata:
#  name: simplest

# resource "kubernetes_manifest" "jaeger-instance" {
#   manifest = {
#     "apiVersion" = "jaegertracing.io/v1"
#     "kind"       = "Jaeger"
#     "metadata" = {
#       "name"      = "simplest-config"
#       "namespace" = local.namespace
#     }
#   }
#   depends_on = [ helm_release.jaeger-operator ]
# }
