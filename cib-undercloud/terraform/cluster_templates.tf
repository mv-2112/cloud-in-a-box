# Public Magnum cluster templates. Tenants look these up by name
# ("generic-k8s-<version>-template"), so the name is the contract between the
# undercloud and the modules repo; don't change it casually.
resource "openstack_containerinfra_clustertemplate_v1" "k8s" {
  for_each              = var.k8s_templates
  name                  = "generic-k8s-${each.key}-template"
  image                 = openstack_images_image_v2.magnum_capi_image[each.key].name
  coe                   = "kubernetes"
  flavor                = each.value.flavor
  master_flavor         = each.value.master_flavor
  dns_nameserver        = join(",", each.value.dns_servers)
  network_driver        = "cilium"
  master_lb_enabled     = true
  external_network_id   = openstack_networking_network_v2.external.id
  public                = true
  docker_storage_driver = "overlay2"
  floating_ip_enabled   = true

  depends_on = [openstack_compute_flavor_v2.flavor, openstack_networking_subnet_v2.external]

  # Labels: https://docs.openstack.org/magnum/latest/user/#cluster-drivers
  # Amphora takes ROUND_ROBIN and health monitors; OVN supports only
  # SOURCE_IP_PORT and no health monitors.
  labels = {
    octavia_provider       = each.value.octavia_provider
    octavia_lb_algorithm   = each.value.octavia_provider == "ovn" ? "SOURCE_IP_PORT" : "ROUND_ROBIN"
    octavia_lb_healthcheck = each.value.octavia_provider == "amphora"
    auto_scaling_enabled   = false
  }
}
