# Stage 2 of the undercloud: what runs INSIDE the admin cluster.
#   ../terraform  (stage 1) creates the cluster
#   ./            (stage 2) installs platform services into it

data "terraform_remote_state" "undercloud" {
  backend = "s3"
  config = {
    bucket                      = "cib-undercloud-tfstate"
    key                         = "undercloud/terraform.tfstate"
    region                      = "RegionOne"
    endpoints                   = { s3 = var.s3_endpoint }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

locals {
  undercloud = data.terraform_remote_state.undercloud.outputs

  # Per-cloud names, so two clouds on one router don't clash:
  # backstage.mz640test.lab.home.arpa. The router's DNS maps them to the
  # ingress's fixed address (stage 1's platform_ingress_ip).
  cloud_name         = try(coalesce(local.undercloud.cloud_name), null)
  name_suffix        = local.cloud_name != null ? "${local.cloud_name}.${var.dns_domain}" : var.dns_domain
  backstage_hostname = var.backstage == null ? null : coalesce(var.backstage.hostname, "backstage.${local.name_suffix}")
}

# The admin cluster's kubeconfig comes from Cluster API, not Magnum:
# Magnum's client certificate is signed by Magnum's CA, which Sunbeam's
# CAPI-built clusters don't trust. ../tools/admin-kubeconfig.sh writes it.
provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig)
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig)
  }
}

# Shared building blocks: the same modules tenants use.
module "addons" {
  source = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/platform-addons?ref=v1.1.1"

  # Magnum's Cinder CSI add-on already creates the StorageClasses
  # (standard, multiattach, default, csi-cinder-sc-delete/-retain), managed
  # by its Helm release; creating them here clashed ("already exists").
  enable_storage_classes = false
  enable_cert_manager    = true
  enable_traefik         = true
  enable_cnpg            = true

  # Stage 1's fixed floating IP (PLATFORM_INGRESS_IP), so DNS can point at
  # Traefik and stay right across rebuilds. null = Octavia picks one.
  ingress_load_balancer_ip = try(local.undercloud.platform_ingress_ip, null)
}

# Platform GitHub Actions runners: serve cib-tenants only.
module "runners" {
  source = "./modules/arc-runners"

  github_repository_url = "https://github.com/${var.github_owner}/${var.platform_runner.repository}"
  github_app            = var.platform_runner_github_app
  github_token          = var.platform_runner_github_token
  max_runners           = var.platform_runner.max_runners
  ca_cert_pem           = local.undercloud.cloud_ca_cert_pem

  depends_on = [module.addons]
}

# Backstage: platform-only, not offered to tenants.
module "backstage" {
  source = "./modules/backstage"
  count  = var.backstage != null ? 1 : 0

  image         = var.backstage.image
  hostname      = local.backstage_hostname
  github_app    = var.backstage_github_app
  storage_class = "standard"

  depends_on = [module.addons]
}
