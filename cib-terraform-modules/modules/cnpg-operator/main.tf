# CloudNativePG operator. Databases are then declared as postgresql.cnpg.io
# Cluster objects by whatever needs one.

resource "helm_release" "cnpg" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
}
