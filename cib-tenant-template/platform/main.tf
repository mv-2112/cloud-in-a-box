# Stage 2: in-cluster services on the cluster built by stage 1.

terraform {
  required_version = ">= 1.9"

  backend "s3" {
    key                         = "platform/terraform.tfstate"
    region                      = "RegionOne"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
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

provider "openstack" {}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket                      = var.state_bucket
    key                         = "infra/terraform.tfstate"
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

# The cluster already exists by now, so configuring providers from it is safe.
# If Magnum's CAPI kubeconfig is still unreliable on your Sunbeam release,
# use the k8s-cluster module's clusterctl helper and point config_path at the file instead.
data "openstack_containerinfra_cluster_v1" "cluster" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

locals {
  kube = data.openstack_containerinfra_cluster_v1.cluster.kubeconfig
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.cluster_ca_certificate
  client_certificate     = local.kube.client_certificate
  client_key             = local.kube.client_key
}

# helm provider 3.x: `kubernetes` is an attribute (= { }), not a block.
provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = local.kube.cluster_ca_certificate
    client_certificate     = local.kube.client_certificate
    client_key             = local.kube.client_key
  }
}

module "addons" {
  source = "git::https://github.com/blackcatengineering/cib-terraform-modules.git//modules/platform-addons?ref=v1.1.1"

  # Turn things on here.
  # Magnum's Cinder CSI add-on already creates standard, multiattach and
  # friends; ask for `standard` (Cinder) explicitly in PVCs: the cluster's
  # default class is node-local storage (csi-rawfile-default).
  enable_storage_classes = false
  enable_cert_manager    = false
  enable_trust_manager   = false
  enable_istio           = false
  enable_ip_masq         = false
  enable_jaeger          = false
  enable_jenkins         = false
  enable_harness         = false

  harness_account_id       = var.harness_account_id
  harness_delegate_token   = var.harness_delegate_token
  harness_manager_endpoint = var.harness_manager_endpoint
}
