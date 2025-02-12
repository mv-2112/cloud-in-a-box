resource "kubernetes_namespace" "harness-ns" {
  metadata {
    labels = {
      harness-injection = "enabled"
    }

    name = "harness"
  }
}

resource "openstack_blockstorage_volume_v3" "harness-home-datavol" {
  name = "harness-home"
  size = 20
}


# resource "kubernetes_persistent_volume_v1" "harness-home-pv" {
#   metadata {
#     name = "harness-home"

#     # annotations = {
#     #   "pv.beta.kubernetes.io/gid" = "1000"
#     # }

#   }
#   spec {
#     storage_class_name = "standard"
#     # claim_ref {
#     #   name = "harness"
#     #   namespace  = "builder-system"
#     # }
#     capacity = {
#       storage = "20Gi"
#     }
#     access_modes = ["ReadWriteMany"]
#     persistent_volume_source {
#       cinder {
#         volume_id = openstack_blockstorage_volume_v3.harness-home-datavol.id
#         fs_type   = "ext4"
#       }
#     }
#   }
# }

# resource "kubernetes_persistent_volume_claim" "harness-home-pvc" {
#   metadata {
#     name      = "harness"
#     namespace = "harness"
#   }
#   spec {
#     access_modes = ["ReadWriteMany"]
#     resources {
#       requests = {
#         storage = "20Gi"
#       }
#     }
#     storage_class_name = "standard"
#     volume_name        = "harness-home"
#   }
# }


resource "kubernetes_deployment" "harness-deployment" {
  metadata {
    name = "harness"
    labels = {
      app = "harness"
    }
    namespace = "harness"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "harness"
      }
    }

    template {
      metadata {
        labels = {
          app = "harness"
        }
      }

      spec {
        container {
          image = "harness/harness"
          name  = "harness"

          resources {
            limits = {
              cpu    = "2000m"
              memory = "2048Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

        #   liveness_probe {
        #     http_get {
        #       path = "/"
        #       port = 80

        #       http_header {
        #         name  = "X-Custom-Header"
        #         value = "Awesome"
        #       }
        #     }

        #     initial_delay_seconds = 3
        #     period_seconds        = 3
        #   }
        }
      }
    }
  }
}


resource "kubernetes_service" "harness-service" {
  metadata {
    name = "harness-svc"
    namespace = "harness"
  }
  spec {

    #     docker run -d \
    #   -p 3000:3000 -p 3022:3022 \
    #   -v /var/run/docker.sock:/var/run/docker.sock \
    #   -v /tmp/harness:/data \
    #   --name opensource \
    #   --restart always \
    #   harness/harness
    selector = {
      app = kubernetes_deployment.harness-deployment.metadata.0.labels.app
    }
    port {
      port        = 3000
      target_port = 3000
      name        = "harness-3000"
    }
    # port {
    #   port        = 3022
    #   target_port = 3022
    #   name        = "harness-3022"

    # }


    type = "LoadBalancer"
  }
}
