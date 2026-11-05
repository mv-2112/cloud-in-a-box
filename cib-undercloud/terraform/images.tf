# Base images published to every tenant.
resource "openstack_images_image_v2" "base" {
  for_each         = var.base_images
  name             = each.key
  image_source_url = each.value.url
  container_format = "bare"
  disk_format      = each.value.disk_format
  visibility       = "public"
  decompress       = each.value.decompress
  tags             = [local.platform_tag]

  properties = merge({
    os_distro       = each.value.os_distro
    architecture    = "x86_64"
    hypervisor_type = "qemu"
  }, each.value.properties)
}

# Magnum CAPI node images, one per Kubernetes template version.
# See https://static.atmosphere.dev/artifacts/magnum-cluster-api/
resource "openstack_images_image_v2" "magnum_capi_image" {
  for_each         = var.k8s_templates
  name             = "coe-capi-${each.key}"
  image_source_url = each.value.coe_os_image
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  tags             = [local.platform_tag]

  properties = {
    os_distro       = "ubuntu"
    architecture    = "x86_64"
    hypervisor_type = "qemu"
    kube_version    = each.value.glance_kube_version
  }
}
