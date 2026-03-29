locals {
  istio_repo = "https://istio-release.storage.googleapis.com/charts"

  is_ambient = var.mode == "ambient"

  enable_cni = var.enable_cni != null ? var.enable_cni : local.is_ambient

  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "istio.io/rev"                 = var.istio_version
    },
    var.tags
  )
}