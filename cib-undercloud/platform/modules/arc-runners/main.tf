# Platform GitHub Actions runners on the admin cluster, using GitHub's
# actions-runner-controller (runner scale sets).
#
# Registered ONLY to the cib-tenants repository, whose jobs carry platform
# admin credentials. Runner pods are ephemeral (one job each) and their
# service account has no Kubernetes permissions.

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.3, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
  }
}

locals {
  controller_namespace = "arc-system"
  runners_namespace    = "arc-runners"
  controller_name      = "arc"
  ca_path              = "/etc/cib/ca.crt"
  use_app              = var.github_app != null
}

resource "helm_release" "controller" {
  name             = local.controller_name
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  version          = var.chart_version
  namespace        = local.controller_namespace
  create_namespace = true
}

resource "kubernetes_namespace_v1" "runners" {
  metadata {
    name = local.runners_namespace
    labels = {
      # Pod Security Admission: runner pods must be non-root, unprivileged.
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# Runner pods run untrusted-ish job code with platform admin credentials in
# their environment. Keep them off the cluster network: no inbound at all,
# and outbound to DNS and anything EXCEPT pod/service networks (GitHub and the
# cloud APIs stay reachable; Backstage, its database and the Kubernetes
# internals don't).
resource "kubernetes_network_policy_v1" "runners" {
  metadata {
    name      = "runners-egress-only"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = var.cluster_internal_cidrs
        }
      }
    }
  }
}

# GitHub credentials for the scale set: a GitHub App (preferred: scoped,
# short-lived tokens) or a fine-grained PAT.
resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = "cib-platform-github"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }

  lifecycle {
    precondition {
      condition     = var.github_app != null || var.github_token != null
      error_message = "Set either github_app or github_token for the platform runners."
    }
  }

  data = local.use_app ? {
    github_app_id              = var.github_app.app_id
    github_app_installation_id = var.github_app.installation_id
    github_app_private_key     = var.github_app.private_key
    } : {
    github_token = var.github_token
  }
}

resource "kubernetes_config_map_v1" "ca" {
  count = var.ca_cert_pem != null ? 1 : 0

  metadata {
    name      = "cloud-ca"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }

  data = {
    "ca.crt" = var.ca_cert_pem
  }
}

resource "helm_release" "scale_set" {
  name      = var.scale_set_name
  namespace = kubernetes_namespace_v1.runners.metadata[0].name

  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = var.chart_version

  values = [yamlencode({
    githubConfigUrl    = var.github_repository_url
    githubConfigSecret = kubernetes_secret_v1.github.metadata[0].name
    runnerScaleSetName = var.scale_set_name
    # The scale-set name is always a label; these let workflows keep
    # `runs-on: [self-hosted, cib]`.
    scaleSetLabels = var.labels
    minRunners     = var.min_runners
    maxRunners     = var.max_runners

    controllerServiceAccount = {
      namespace = local.controller_namespace
      name      = "${local.controller_name}-gha-rs-controller"
    }

    template = {
      spec = {
        securityContext = {
          runAsNonRoot   = true
          seccompProfile = { type = "RuntimeDefault" }
        }
        automountServiceAccountToken = false
        containers = [{
          name = "runner"
          # The image grants passwordless sudo; this switches it off. Jobs
          # here only need Terraform, which needs no root.
          securityContext = {
            allowPrivilegeEscalation = false
            capabilities             = { drop = ["ALL"] }
          }
          image   = "ghcr.io/actions/actions-runner:${var.runner_image_tag}"
          command = ["/home/runner/run.sh"]
          # Trust the cloud's CA for OpenStack and S3 calls without replacing
          # the system bundle GitHub's own TLS relies on.
          env = var.ca_cert_pem == null ? [] : [
            { name = "OS_CACERT", value = local.ca_path },
            { name = "AWS_CA_BUNDLE", value = local.ca_path },
          ]
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { memory = "2Gi" }
          }
          volumeMounts = var.ca_cert_pem == null ? [] : [
            { name = "cloud-ca", mountPath = "/etc/cib", readOnly = true },
          ]
        }]
        volumes = var.ca_cert_pem == null ? [] : [
          { name = "cloud-ca", configMap = { name = "cloud-ca" } },
        ]
      }
    }
  })]

  depends_on = [helm_release.controller, kubernetes_config_map_v1.ca]
}
