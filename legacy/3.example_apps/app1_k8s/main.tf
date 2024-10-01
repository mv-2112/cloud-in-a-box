# Setup our Websphere Liberty

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}


resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.app_project}-keypair"
}


resource "openstack_containerinfra_clustertemplate_v1" "clustertemplate_1" {
  name                  = "${var.app_project}-k8s-template"
  image                 = var.default_image
  coe                   = "kubernetes"
  flavor                = "m1.small"
  master_flavor         = "m1.small"
  dns_nameserver        = var.dns_server
  docker_storage_driver = "overlay2"
  docker_volume_size    = 15
  volume_driver         = "cinder"
  network_driver        = "flannel"
  server_type           = "vm"
  master_lb_enabled     = false
  floating_ip_enabled   = true
  tls_disabled          = false
  public                = false
  registry_enabled      = false
  external_network_id   = data.openstack_networking_network_v2.external_network.name
  # fixed_network         = "${var.app_project}-${var.domain}-network"
  # fixed_subnet          = "${var.app_project}-subnet-1"

  labels = {
    # Labels documented here https://docs.openstack.org/magnum/latest/user/#cluster-drivers
    # https://github.com/kubernetes/k8s.io/blob/main/registry.k8s.io/images/k8s-staging-provider-os/images.yaml
    # https://console.cloud.google.com/gcr/images/k8s-artifacts-prod/EU/sig-storage for csi-resizer etc
    # kube_tag                         = var.kube_release
    # calico_tag                       = "v3.26.4"
    # containerd_runtime               = "containerd"
    # containerd_version               = "1.6.31"
    # kube_dashboard_enabled           = "false"
    # prometheus_monitoring            = "false"
    # influx_grafana_dashboard_enabled = "false"
    cloud_provider_tag               = var.k8s-staging-provider-os
    cinder_csi_plugin_tag            = var.k8s-staging-provider-os
    # csi_attacher_tag                 = "v4.2.0"
    # csi_provisioner_tag              = "v3.2.2"
    # csi_snapshotter_tag              = "v6.2.1"
    # csi_resizer_tag                  = "v1.7.0"
    # csi_node_driver_registrar_tag    = "v2.6.3"
    k8s_keystone_auth_tag            = var.k8s-staging-provider-os
    # octavia_ingress_controller_tag   = var.k8s-staging-provider-os
    # octavia_provider                 = "ovn"
    # octavia_lb_algorithm             = "SOURCE_IP_PORT"
    # magnum_auto_healer_tag           = var.k8s-staging-provider-os
  }
}

resource "openstack_containerinfra_cluster_v1" "cluster_1" {
  name                = "${var.app_project}-k8s-cluster"
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.clustertemplate_1.id
  master_count        = 1
  node_count          = 1
  keypair             = openstack_compute_keypair_v2.keypair.id
  create_timeout      = 1440
  # added as when creating with terraform gets ignored from template
  floating_ip_enabled = true
}

# resource "openstack_containerinfra_nodegroup_v1" "nodegroup_1" {
#   name       = "${var.app_project}-k8s-nodegroup-1"
#   cluster_id = openstack_containerinfra_cluster_v1.cluster_1.id
#   node_count = 2
# }

# resource "openstack_containerinfra_nodegroup_v1" "nodegroup_2" {
#   name       = "${var.app_project}-k8s-nodegroup-2"
#   cluster_id = openstack_containerinfra_cluster_v1.cluster_1.id
#   node_count = 2
# }
