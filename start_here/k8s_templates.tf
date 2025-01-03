resource "openstack_containerinfra_clustertemplate_v1" "clustertemplate_1" {
  name                  = "generic-k8s-v1.27.8-template"
  image                 = openstack_images_image_v2.fedora_coreos.id
  coe                   = "kubernetes"
  flavor                = "m1.large"
  master_flavor         = "m1.medium"
  dns_nameserver        = join(",", [for s in var.dns_servers : format("%s", s)])
  docker_storage_driver = "overlay2"
  docker_volume_size    = 15
  volume_driver         = "cinder"
  network_driver        = "calico"
  server_type           = "vm"
  master_lb_enabled     = true
  floating_ip_enabled   = true
  tls_disabled          = false
  public                = true
  registry_enabled      = false
  external_network_id   = data.openstack_networking_network_v2.external_network.name

  #  Labels documented here https://docs.openstack.org/magnum/latest/user/#cluster-drivers
  #  https://github.com/kubernetes/k8s.io/blob/main/registry.k8s.io/images/k8s-staging-provider-os/images.yaml
  #  https://console.cloud.google.com/gcr/images/k8s-artifacts-prod/EU/sig-storage for csi-resizer etc

  labels = {

    kube_tag                       = "v1.27.8-rancher2"
    container_runtime              = "containerd"
    containerd_version             = "1.6.28"
    containerd_tarball_sha256      = "f70736e52d61e5ad225f4fd21643b5ca1220013ab8b6c380434caeefb572da9b"
    cloud_provider_tag             = "v1.27.3"
    cinder_csi_plugin_tag          = "v1.27.3"
    k8s_keystone_auth_tag          = "v1.27.3"
    magnum_auto_healer_tag         = "v1.27.3"
    octavia_ingress_controller_tag = "v1.27.3"
    calico_tag                     = "v3.26.4"
    octavia_provider               = "ovn"
    octavia_lb_algorithm           = "SOURCE_IP_PORT"
  }
}
