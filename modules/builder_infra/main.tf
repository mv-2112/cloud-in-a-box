data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}

data "openstack_containerinfra_clustertemplate_v1" "cluster_template" {
  name = var.k8s_template
}

locals {
  domain_safename = replace(var.domain, ".", "_")
}


resource "random_string" "suffix" {
  length  = 5
  special = false
  lower   = true
  upper   = false
}


resource "openstack_compute_keypair_v2" "keypair" {
  name = "builder-keypair"
}

resource "openstack_networking_network_v2" "network" {
  name           = "${local.domain_safename}-network"
  admin_state_up = "true"
}


resource "openstack_networking_subnet_v2" "subnet" {
  name            = "${local.domain_safename}-subnet-1"
  network_id      = openstack_networking_network_v2.network.id
  cidr            = "192.168.1.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_servers
}


resource "openstack_networking_router_v2" "router_1" {
  name                = "${local.domain_safename}-router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
}


resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = openstack_networking_router_v2.router_1.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_containerinfra_cluster_v1" "cluster_1" {
  name                = "builder-cluster-${random_string.suffix.result}"
  cluster_template_id = data.openstack_containerinfra_clustertemplate_v1.cluster_template.id
  master_count        = 1
  node_count          = 1
  keypair             = openstack_compute_keypair_v2.keypair.id
  # create_timeout      = 1440
  # added as when creating with terraform gets ignored from template
  # floating_ip_enabled = true


}

# resource "kubernetes_namespace" "istio-system" {
#   metadata {
#     # annotations = {
#     #   name = "istio-system"
#     # }

#     # labels = {
#     #   mylabel = "istio-system"
#     # }

#     name = "istio-system"
#   }
# }

# resource "kubernetes_storage_class" "csi-sc-cinder" {
#   metadata {
#     name = "standard"
#     annotations = {
#       "storageclass.kubernetes.io/is-default-class" = "true"
#     }
#   }
#   storage_provisioner = "cinder.csi.openstack.org"
#   reclaim_policy      = "Delete"
#   parameters = {
#     type         = "standard"
#     availability = "nova"
#   }
#   # mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
#   allow_volume_expansion = true
#   volume_binding_mode    = "Immediate"
#   depends_on             = [openstack_containerinfra_cluster_v1.cluster_1, local_sensitive_file.builder_k8s_config]
# }


module "storage-classes" {
  source        = "../storage-classes"
  k8s_cluster   = openstack_containerinfra_cluster_v1.cluster_1.name
  providers = {
    kubernetes = kubernetes.kubernetes_config
  }

  depends_on = [ openstack_containerinfra_cluster_v1.cluster_1, local_sensitive_file.builder_k8s_config ]
}


module "builder-istio" {
  count         = (var.enable_istio) ? 1 : 0
  source        = "../istio"
  k8s_cluster   = openstack_containerinfra_cluster_v1.cluster_1.name
  istio_version = "1.23.4"
  # domain  = "example.com"
  providers = {
    helm       = helm.helm_config
    kubernetes = kubernetes.kubernetes_config
  }

  depends_on = [ openstack_containerinfra_cluster_v1.cluster_1, local_sensitive_file.builder_k8s_config ]
}

module "builder-jenkins" {
  count         = (var.enable_istio) ? 1 : 0
  source        = "../jenkins"
  k8s_cluster   = openstack_containerinfra_cluster_v1.cluster_1.name
  # domain  = "example.com"
  providers = {
    helm       = helm.helm_config
    kubernetes = kubernetes.kubernetes_config
  }

  depends_on = [ openstack_containerinfra_cluster_v1.cluster_1, local_sensitive_file.builder_k8s_config ]
}


