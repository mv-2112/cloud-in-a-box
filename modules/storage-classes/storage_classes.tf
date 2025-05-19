resource "kubernetes_storage_class" "csi-sc-cinder-standard" {
  metadata {
    name = "standard"
    # annotations = { 
    #   "storageclass.kubernetes.io/is-default-class" = "true"
    # }
  }
  storage_provisioner = "cinder.csi.openstack.org"
  reclaim_policy      = "Delete"
  parameters = {
    type = "standard"
    availability = "nova"
  }
  # mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
  allow_volume_expansion = true
  # volume_binding_mode = "Immediate"
  volume_binding_mode = "WaitForFirstConsumer"
}


resource "kubernetes_storage_class" "csi-sc-cinder-multiattach" {
  metadata {
    name = "multiattach"
    annotations = { 
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "cinder.csi.openstack.org"
  reclaim_policy      = "Delete"
  parameters = {
    type = "multiattach"
    availability = "nova"
  }
  # mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
  allow_volume_expansion = true
  # volume_binding_mode = "Immediate"
  volume_binding_mode = "WaitForFirstConsumer"
}