terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Template is published by cib-undercloud; this name is the contract.
data "openstack_containerinfra_clustertemplate_v1" "template" {
  name = "generic-k8s-${var.kubernetes_version}-template"
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "openstack_containerinfra_cluster_v1" "cluster" {
  name                = "${var.name}-${random_string.suffix.result}"
  cluster_template_id = data.openstack_containerinfra_clustertemplate_v1.template.id
  master_count        = var.master_count
  node_count          = var.node_count
  keypair             = var.keypair_name
  create_timeout      = var.create_timeout
  fixed_network       = var.fixed_network
  fixed_subnet        = var.fixed_subnet
}

locals {
  kubeconfig_path = "${var.output_dir}/${openstack_containerinfra_cluster_v1.cluster.name}/kubeconfig"
}

# Preferred path: Magnum hands back the kubeconfig directly.
resource "local_sensitive_file" "kubeconfig" {
  count           = var.kubeconfig_source == "magnum" ? 1 : 0
  filename        = local.kubeconfig_path
  content         = openstack_containerinfra_cluster_v1.cluster.kubeconfig.raw_config
  file_permission = "0600"
}

# Workaround carried over from builder-infra: with the CAPI driver the Magnum
# kubeconfig was unreliable, so pull it from the management cluster instead.
# Only works when run on the Sunbeam host itself.
resource "local_file" "clusterctl_kubeconfig_script" {
  count           = var.kubeconfig_source == "clusterctl" ? 1 : 0
  filename        = "${var.output_dir}/fetch_kubeconfig.sh"
  file_permission = "0750"
  content         = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    sudo k8s config > /tmp/mgmt-kubeconfig
    mkdir -p "$(dirname ${local.kubeconfig_path})"
    KUBECONFIG=/tmp/mgmt-kubeconfig clusterctl get kubeconfig \
      --namespace magnum-${openstack_containerinfra_cluster_v1.cluster.project_id} \
      ${openstack_containerinfra_cluster_v1.cluster.stack_id} > ${local.kubeconfig_path}
    chmod 600 ${local.kubeconfig_path}
  EOT
}
