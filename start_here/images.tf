# resource "openstack_images_image_v2" "fedora_coreos" {
#   for_each         = toset(distinct([for i in var.k8s_templates : "${i.core_os_image}"]))
#   name             = "fedora-coreos-${each.key}"
#   image_source_url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${each.key}/x86_64/fedora-coreos-${each.key}-openstack.x86_64.qcow2.xz"
#   container_format = "bare"
#   disk_format      = "qcow2"
#   visibility       = "public"
#   decompress       = true

#   properties = {
#     os_distro       = "fedora-coreos"
#     architecture    = "x86_64"
#     hypervisor_type = "qemu"
#   }
# }


# For Magnum CAPI images until i can roll my own. These are at least Vexxhost
# https://static.atmosphere.dev/artifacts/magnum-cluster-api/
# Naming is in this style: ubuntu-jammy-kubernetes-1-31-1-1742226216.qcow2 

# openstack image create ${IMAGE_NAME} --disk-format=qcow2 --container-format=bare --property os_distro=${OS_DISTRO} --file=${IMAGE_NAME}.qcow2; \
resource "openstack_images_image_v2" "magnum_capi_image" {
  for_each         = var.k8s_templates
  name             = "coe-capi-${each.key}"
  image_source_url = each.value.coe_os_image
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"

  properties = {
    os_distro       = "ubuntu"
    architecture    = "x86_64"
    hypervisor_type = "qemu"
    kube_version    = "${each.value.glance_kube_version}"
  }
}
