resource "openstack_images_image_v2" "fedora_coreos" {
  name             = "fedora-coreos-${var.default_coreos_image}"
  image_source_url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${var.default_coreos_image}/x86_64/fedora-coreos-${var.default_coreos_image}-openstack.x86_64.qcow2.xz"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
  decompress       = true

  properties = {
    os_distro = "fedora-coreos"
  }
}
