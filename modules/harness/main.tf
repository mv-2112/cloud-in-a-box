module "delegate" {
  source = "harness/harness-delegate/kubernetes"
  version = "0.2.0"
  account_id = var.account_id
  delegate_token = var.delegate_token
  delegate_name = "terraform-delegate"
  deploy_mode = "KUBERNETES"
  namespace = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image = "harness/delegate:25.03.85403"
  replicas = 1
  upgrader_enabled = true
}