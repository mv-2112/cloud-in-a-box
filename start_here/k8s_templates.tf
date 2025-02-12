resource "openstack_containerinfra_clustertemplate_v1" "clustertemplate" {
  for_each = var.k8s_templates
  name                  = "generic-k8s-${each.key}-template"
  image                 = openstack_images_image_v2.fedora_coreos[each.value.core_os_image].id
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

    kube_tag                       = each.key
    container_runtime              = each.value.container_runtime
    containerd_version             = each.value.containerd_version
    containerd_tarball_sha256      = each.value.containerd_tarball_sha256
    cloud_provider_tag             = each.value.cloud_provider_tag
    cinder_csi_plugin_tag          = each.value.cinder_csi_plugin_tag
    k8s_keystone_auth_tag          = each.value.k8s_keystone_auth_tag
    magnum_auto_healer_tag         = each.value.magnum_auto_healer_tag
    octavia_ingress_controller_tag = each.value.octavia_ingress_controller_tag
    calico_tag                     = each.value.calico_tag
    octavia_provider               = each.value.octavia_provider
    octavia_lb_algorithm           = each.value.octavia_lb_algorithm
    # Added to hopefully keep LB's live - may still not solve no traffic issue...
    octavia_lb_healthcheck         = each.value.octavia_lb_healthcheck

  }
}