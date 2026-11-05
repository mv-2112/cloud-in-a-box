# In-cluster platform services. Contains NO provider blocks: the calling root
# module configures `helm` and `kubernetes` against an existing cluster's
# kubeconfig. Run this in a separate stage/root from k8s-cluster, because
# Terraform can't configure a provider from a cluster created in the same plan.

terraform {
  # 1.9+ for cross-variable validation (trust-manager needs cert-manager)
  required_version = ">= 1.9"

  required_providers {
    # helm provider 3.x is the current line (there is no 4.x yet) and embeds
    # the Helm v3 SDK. Helm 4 still installs apiVersion v2 charts, so a Helm 4
    # based provider should be a version bump here, not a module rewrite.
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.3, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
  }
}

module "istio" {
  source = "../istio"
  count  = var.enable_istio ? 1 : 0

  istio_version   = var.istio_version
  istio_namespace = "istio-system"
  enable_ambient  = var.enable_istio_ambient
  enable_gateway  = true
}

module "ip_masq" {
  source = "../ip-masq-agent"
  count  = var.enable_ip_masq ? 1 : 0

  nonmasquerade_cidrs = var.ip_masq_nonmasquerade_cidrs
}

module "storage_classes" {
  source = "../storage-classes"
  count  = var.enable_storage_classes ? 1 : 0

  default_class = var.default_storage_class
}

module "traefik" {
  source = "../traefik"
  count  = var.enable_traefik ? 1 : 0

  load_balancer_ip = var.ingress_load_balancer_ip
}

module "cnpg_operator" {
  source = "../cnpg-operator"
  count  = var.enable_cnpg ? 1 : 0
}

module "cert_manager" {
  source = "../cert-manager"
  count  = var.enable_cert_manager ? 1 : 0
}

module "trust_manager" {
  source = "../trust-manager"
  count  = var.enable_trust_manager ? 1 : 0

  depends_on = [module.cert_manager]
}

module "jaeger" {
  source = "../jaeger"
  count  = var.enable_jaeger ? 1 : 0

  depends_on = [module.cert_manager]
}

module "jenkins" {
  source = "../jenkins"
  count  = var.enable_jenkins ? 1 : 0

  depends_on = [module.istio]
}

module "harness" {
  source = "../harness"
  count  = var.enable_harness ? 1 : 0

  account_id       = var.harness_account_id
  delegate_token   = var.harness_delegate_token
  manager_endpoint = var.harness_manager_endpoint
}
