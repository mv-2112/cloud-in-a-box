resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istio-base"
  version          = var.istio_version
  namespace        = var.istio_namespace
  create_namespace = true

  # Custom values for istio-base
  values = [var.istio_base_values]
}

# --- Istio Control Plane (istiod) ---
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = var.istio_namespace
  depends_on = [helm_release.istio_base]

  # Custom values for istiod (ambient mode, sidecar injection, etc.)
  values = [
    <<-EOT
    ${var.istiod_values}
    pilot:
      autoscaleEnabled: true
    sidecarInjectorWebhook:
      enabled: ${var.enable_ambient ? "false" : "true"}
    ambient:
      enabled: ${var.enable_ambient}
    EOT
  ]
}

# --- Istio Ingress Gateway (Optional) ---
resource "helm_release" "istio_ingress" {
  count = var.enable_gateway && !var.enable_ambient ? 1 : 0

  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = var.istio_namespace
  depends_on = [helm_release.istiod]

  # Custom values for gateway
  values = [var.gateway_values]
}