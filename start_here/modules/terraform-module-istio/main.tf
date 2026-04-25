resource "helm_release" "base" {
  name             = "istio-base"
  repository       = local.istio_repo
  chart            = "base"
  version          = var.istio_version
  namespace        = var.namespace
  create_namespace = true

  dynamic "set" {
    for_each = local.is_ambient ? [] : [1]
    content {
      name  = "defaultRevision"
      value = var.istio_version
    }
  }
}

resource "helm_release" "istiod" {
  name             = "istiod-${var.istio_version}"
  repository       = local.istio_repo
  chart            = "istiod"
  version          = var.istio_version
  namespace        = var.namespace
  create_namespace = true

  depends_on = [helm_release.base]

  dynamic "set" {
    for_each = local.is_ambient ? [1] : []
    content {
      name  = "profile"
      value = "ambient"
    }
  }

  set {
    name  = "revision"
    value = var.istio_version
  }

  values = var.istiod_values
}

resource "helm_release" "cni" {
  count = local.enable_cni ? 1 : 0

  name             = "istio-cni"
  repository       = local.istio_repo
  chart            = "cni"
  version          = var.istio_version
  namespace        = var.namespace
  create_namespace = true

  depends_on = [helm_release.base]

  dynamic "set" {
    for_each = local.is_ambient ? [1] : []
    content {
      name  = "profile"
      value = "ambient"
    }
  }
}

resource "helm_release" "ztunnel" {
  count = local.is_ambient ? 1 : 0

  name             = "ztunnel"
  repository       = local.istio_repo
  chart            = "ztunnel"
  version          = var.istio_version
  namespace        = var.namespace
  create_namespace = true

  depends_on = [
    helm_release.istiod,
    helm_release.cni
  ]
}

resource "helm_release" "ingress" {
  count = var.enable_ingress ? 1 : 0

  name             = "istio-ingress-${var.istio_version}"
  repository       = local.istio_repo
  chart            = "gateway"
  version          = var.istio_version
  namespace        = var.ingress_namespace
  create_namespace = true

  depends_on = [helm_release.istiod]

  values = var.gateway_values

  set {
    name  = "revision"
    value = var.istio_version
  }
}

resource "helm_release" "egress" {
  count = var.enable_egress ? 1 : 0

  name             = "istio-egress-${var.istio_version}"
  repository       = local.istio_repo
  chart            = "gateway"
  version          = var.istio_version
  namespace        = var.egress_namespace
  create_namespace = true

  depends_on = [helm_release.istiod]

  values = var.gateway_values

  set {
    name  = "revision"
    value = var.istio_version
  }
}
