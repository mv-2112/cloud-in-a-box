locals {
  jenkins_charts_url = "https://charts.jenkins.io"
}



resource "helm_release" "jenkins" {
  repository = local.jenkins_charts_url
  chart      = "jenkins"
  name       = "jenkins"
  namespace  = "builder-system"
  create_namespace = true


  # set {
  #   name  = "controller.ingress.enabled"
  #   value = "true"
  # }

  # set {
  #   name  = "controller.ingress.paths"
  #   value = "[]"
  # }

  # set {
  #   name  = "controller.ingress.apiVersion"
  #   value = "extensions/v1beta1"
  # }

  # set {
  #   name  = "controller.ingress.hostName"
  #   value = "jenkins.example.com"
  # }

  # set {
  #   name  = "persistence.existingClaim"
  #   value = kubernetes_persistent_volume_claim.jenkins-home-pvc.metadata[0].name
  # }

  set {
    name = "controller.serviceType"
    value = "LoadBalancer"
  }

  set {
    name  = "podSecurityContextOverride.runAsUser"
    value = 1000
  }

  set {
    name  = "podSecurityContextOverride.fsGroup"
    value = 1000
  }

  set {
    name  = "podSecurityContextOverride.fsGroupChangePolicy"
    value = "OnRootMismatch"
  }

  set {
    name  = "podSecurityContextOverride.supplementalGroups"
    value = 1000
  }

}


# resource "openstack_blockstorage_volume_v3" "jenkins-home-datavol" {
#   name = "jenkins-home"
#   size = 20
# }


# resource "kubernetes_persistent_volume_v1" "jenkins-home-pv" {
#   metadata {
#     name = "jenkins-home"
#     # annotations = {
#     #   "pv.beta.kubernetes.io/gid" = "1000"
#     # }

#   }
#   spec {
#     storage_class_name = "standard"
#     # claim_ref {
#     #   name = "jenkins"
#     #   namespace  = "builder-system"
#     # }
#     capacity = {
#       storage = "20Gi"
#     }
#     access_modes = ["ReadWriteMany"]
#     persistent_volume_source {
#       cinder {
#         volume_id = openstack_blockstorage_volume_v3.jenkins-home-datavol.id
#         fs_type   = "ext4"
#       }
#     }
#   }
# }

# resource "kubernetes_persistent_volume_claim" "jenkins-home-pvc" {
#   metadata {
#     name      = "jenkins"
#     namespace = "builder-system"
#   }
#   spec {
#     access_modes = ["ReadWriteMany"]
#     resources {
#       requests = {
#         storage = "20Gi"
#       }
#     }
#     storage_class_name = "standard"
#     volume_name        = "jenkins-home"
#   }
# }
