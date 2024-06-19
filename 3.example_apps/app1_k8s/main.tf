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
  network_driver      = "flannel"
  server_type         = "vm"
  master_lb_enabled   = true
  floating_ip_enabled = true
  tls_disabled        = false
  public              = false
  registry_enabled    = false
  external_network_id = data.openstack_networking_network_v2.external_network.name
  # fixed_network         = "${var.app_project}-${var.domain}-network"
  # fixed_subnet          = "${var.app_project}-subnet-1"

  labels = {
    # kube_tag = var.kube_release
    # kube_dashboard_enabled           = "false"
    # prometheus_monitoring            = "false"
    # influx_grafana_dashboard_enabled = "false"
    octavia_provider     = "ovn"
    octavia_lb_algorithm = "SOURCE_IP_PORT"
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
