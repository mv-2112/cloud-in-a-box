variable "image" {
  description = <<-EOT
    Backstage image built per Backstage-Testbed. Prefer pinning by digest so a
    re-pushed tag can't change what runs:
      docker buildx imagetools inspect docker.io/verranm/backstage:0.0.93 --format '{{json .Manifest.Digest}}'
    then use "docker.io/verranm/backstage@sha256:...".
  EOT
  type        = string
  default     = "docker.io/verranm/backstage:0.0.93"
}

variable "hostname" {
  description = "Public hostname; overrides the baseUrls baked into the image. Must match the GitHub App's callback URL."
  type        = string
  default     = "backstage.local"
}

variable "github_app" {
  description = "Backstage's GitHub App (see Backstage-Testbed README for permissions)."
  type = object({
    app_id        = string
    client_id     = string
    client_secret = string
    private_key   = string
  })
  sensitive = true
}

variable "namespace" {
  type    = string
  default = "backstage"
}

variable "replicas" {
  type    = number
  default = 1
}

variable "ingress_class" {
  type    = string
  default = "traefik"
}

variable "cluster_issuer" {
  type    = string
  default = "backstage-selfsigned-issuer"
}

variable "create_self_signed_issuer" {
  description = "Create cluster_issuer as a self-signed issuer. Set false when pointing at your own issuer."
  type        = bool
  default     = true
}

variable "storage_class" {
  type    = string
  default = "standard"
}

variable "database_instances" {
  type    = number
  default = 1
}

variable "database_size" {
  type    = string
  default = "10Gi"
}

variable "ingress_namespace" {
  description = "Namespace of the ingress controller; the only source allowed to reach Backstage."
  type        = string
  default     = "traefik"
}

variable "cnpg_namespace" {
  description = "CloudNativePG operator namespace; allowed to reach the database's status port."
  type        = string
  default     = "cnpg-system"
}
