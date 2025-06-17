# https://raw.githubusercontent.com/kubernetes-sigs/ip-masq-agent/master/ip-masq-agent.yaml
locals {
  ip_masq_agent_url = "https://raw.githubusercontent.com/kubernetes-sigs/ip-masq-agent/master/ip-masq-agent.yaml"
}

# apiVersion: apps/v1
# kind: DaemonSet
# metadata:
#   name: ip-masq-agent
#   namespace: kube-system
# spec:
#   selector:
#     matchLabels:
#       k8s-app: ip-masq-agent
#   template:
#     metadata:
#       labels:
#         k8s-app: ip-masq-agent
#     spec:
#       hostNetwork: true
#       containers:
#       - name: ip-masq-agent
#         image: registry.k8s.io/networking/ip-masq-agent:v2.8.0
#         securityContext:
#           privileged: false
#           capabilities:
#             add: ["NET_ADMIN", "NET_RAW"]
#         volumeMounts:
#           - name: config
#             mountPath: /etc/config
#       volumes:
#         - name: config
#           configMap:
#             # Note this ConfigMap must be created in the same namespace as the daemon pods - this spec uses kube-system
#             name: ip-masq-agent
#             optional: true
#             items:
#               # The daemon looks for its config in a YAML file at /etc/config/ip-masq-agent
#               - key: config
#                 path: ip-masq-agent

resource "kubernetes_daemonset" "ip-masq-agent" {
  metadata {
    name      = "ip-masq-agent"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "ip-masq-agent"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "ip-masq-agent"
        }
      }

      spec {
        host_network = true
        container {
          image = "registry.k8s.io/networking/ip-masq-agent:v2.8.0"
          name  = "ip-masq-agent"
          security_context {
            privileged = true
            capabilities {
              add = ["NET_ADMIN", "NET_RAW"]
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
}

