# StorageClasses backed by Cinder CSI, one per volume type published by
# cib-undercloud (`standard`, `multiattach`).

resource "kubernetes_storage_class_v1" "cinder" {
  for_each = var.storage_classes

  metadata {
    name = each.key
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = tostring(each.key == var.default_class)
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner    = "cinder.csi.openstack.org"
  reclaim_policy         = each.value.reclaim_policy
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type         = each.value.volume_type
    availability = var.availability_zone
  }
}
