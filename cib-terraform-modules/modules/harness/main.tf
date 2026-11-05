# Harness delegate: the official harness-delegate-ng chart, installed the way
# Harness's docs do it with Helm:
#   https://developer.harness.io/harness-platform/use-harness-platform/delegates/delegate/install-delegates/overview
#   helm upgrade -i <name> harness-delegate/harness-delegate-ng --set accountId=... --set delegateToken=... ...
# Harness's Terraform module wraps exactly this helm_release, but its registry
# releases (up to 0.2.4) need the helm provider < 3, so it can't sit beside
# these modules. The chart itself has no such limit.

resource "helm_release" "delegate" {
  name             = var.delegate_name
  repository       = "https://app.harness.io/storage/harness-download/delegate-helm-chart/"
  chart            = "harness-delegate-ng"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600

  values = compact([
    yamlencode({
      accountId           = var.account_id
      managerEndpoint     = var.manager_endpoint
      delegateName        = var.delegate_name
      delegateDockerImage = var.delegate_image
      replicas            = var.replicas
      upgrader            = { enabled = var.upgrader_enabled }
      deployMode          = "KUBERNETES"
    }),
    var.extra_values,
  ])

  # The token never goes into the rendered values (or plan output).
  set_sensitive = [{
    name  = "delegateToken"
    value = var.delegate_token
    type  = "string"
  }]
}
