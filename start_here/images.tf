resource "openstack_images_image_v2" "fedora_coreos" {
  for_each         = toset(distinct([for i in var.k8s_templates : "${i.core_os_image}"]))
  name             = "fedora-coreos-${each.key}"
  image_source_url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${each.key}/x86_64/fedora-coreos-${each.key}-openstack.x86_64.qcow2.xz"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  decompress       = true

  properties = {
    os_distro       = "fedora-coreos"
    architecture    = "x86_64"
    hypervisor_type = "qemu"
  }
}
