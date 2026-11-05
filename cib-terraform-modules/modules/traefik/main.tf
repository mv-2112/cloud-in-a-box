# Traefik ingress controller. Its Service is type LoadBalancer, which on
# Magnum becomes an Octavia load balancer. HTTP is permanently redirected to HTTPS.
# Routes are plain Kubernetes Ingress objects (ingressClassName: traefik), so
# apps don't depend on Traefik CRDs.

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    ingressClass = {
      enabled        = true
      isDefaultClass = var.default_ingress_class
    }
    ports = {
      web = {
        http = {
          redirections = {
            entryPoint = { to = "websecure", scheme = "https", permanent = true }
          }
        }
      }
    }
    service = {
      # With a fixed address: the OpenStack cloud controller attaches that
      # (pre-created) floating IP instead of allocating a random one, and
      # keeps it when the Service goes away, so DNS can point at it.
      annotations = merge(
        var.load_balancer_ip != null ? { "loadbalancer.openstack.org/keep-floatingip" = "true" } : {},
        var.service_annotations,
      )
      spec = var.load_balancer_ip != null ? { loadBalancerIP = var.load_balancer_ip } : {}
    }
  })]
}

data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = var.namespace
  }
  depends_on = [helm_release.traefik]
}
