# ip-masq-agent: https://github.com/kubernetes-sigs/ip-masq-agent
# Mirrors upstream ip-masq-agent.yaml, with the image as a variable and an
# optional config map instead of relying on built-in defaults.

locals {
  labels = {
    k8s-app                        = "ip-masq-agent"
    "app.kubernetes.io/name"       = "ip-masq-agent"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  # Only rendered when nonmasquerade_cidrs is set. With no config map the agent
  # masquerades everything except the RFC 1918 ranges.
  agent_config = yamlencode({
    nonMasqueradeCIDRs = var.nonmasquerade_cidrs
    masqLinkLocal      = var.masq_link_local
    resyncInterval     = var.resync_interval
  })
}

resource "kubernetes_config_map_v1" "config" {
  count = length(var.nonmasquerade_cidrs) > 0 ? 1 : 0

  metadata {
    name      = "ip-masq-agent"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    config = local.agent_config
  }
}

resource "kubernetes_daemon_set_v1" "ip_masq_agent" {
  metadata {
    name      = "ip-masq-agent"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "ip-masq-agent"
      }
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          # Roll the pods when the config changes.
          "checksum/config" = sha256(local.agent_config)
        }
      }

      spec {
        host_network        = true
        priority_class_name = "system-node-critical"

        # Run on every node, control plane included.
        toleration {
          operator = "Exists"
        }

        container {
          name  = "ip-masq-agent"
          image = "${var.image}:${var.image_tag}"

          security_context {
            # Upstream runs unprivileged with just these capabilities; the old
            # module's privileged = true wasn't needed.
            privileged = false
            capabilities {
              add = ["NET_ADMIN", "NET_RAW"]
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/config"
          }
        }

        volume {
          name = "config"
          config_map {
            name     = "ip-masq-agent"
            optional = true
            items {
              key  = "config"
              path = "ip-masq-agent"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map_v1.config]
}
