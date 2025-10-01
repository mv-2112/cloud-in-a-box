resource "openstack_containerinfra_clustertemplate_v1" "clustertemplate_CAPI" {
  for_each              = var.k8s_templates
  name                  = "generic-k8s-${each.key}-template"
  image                 = "coe-capi-${each.key}"
  coe                   = "kubernetes"
  flavor                = "m1.large"
  master_flavor         = "m1.medium"
  dns_nameserver        = join(",", [for s in each.value.dns_servers : format("%s", s)])
  docker_storage_driver = "overlay2"
  network_driver        = "cilium"
  # server_type           = "vm"
  master_lb_enabled   = true
  floating_ip_enabled = true
  # tls_disabled          = false
  public              = true
  registry_enabled    = false
  insecure_registry   = false
  external_network_id = data.openstack_networking_network_v2.external_network.name

  #  Labels documented here https://docs.openstack.org/magnum/latest/user/#cluster-drivers
  #  https://github.com/kubernetes/k8s.io/blob/main/registry.k8s.io/images/k8s-staging-provider-os/images.yaml
  #  https://console.cloud.google.com/gcr/images/k8s-artifacts-prod/EU/sig-storage for csi-resizer etc

  labels = {
    octavia_provider        = "ovn"
    # https://github.com/canonical/openstack-capi-k8s-helm-charts/pkgs/container/charts%2Fopenstack-ck8s-cluster
    capi_helm_chart_version = "0.1.0"
    keystone_auth_enabled   = true
    kube_tag                = each.value.kube_tag
  }
}
