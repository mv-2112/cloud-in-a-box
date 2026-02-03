module "delegate" {
  source = "harness/harness-delegate/kubernetes"
  version = "0.2.3"
  account_id = var.account_id
  delegate_token = var.delegate_token
  delegate_name = "terraform-delegate"
  deploy_mode = "KUBERNETES"
  namespace = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image = "us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:26.01.88303"
  replicas = 1
  upgrader_enabled = true
}