variable "enable_istio" {
  type    = bool
  default = false
}

variable "enable_istio_ambient" {
  type    = bool
  default = false
}

variable "istio_version" {
  type    = string
  default = "1.29"
}

variable "enable_ip_masq" {
  type    = bool
  default = false
}

variable "ip_masq_nonmasquerade_cidrs" {
  description = "Passed to ip-masq-agent; empty keeps the agent's RFC 1918 default."
  type        = list(string)
  default     = []
}

variable "enable_storage_classes" {
  description = <<-EOT
    Cinder CSI StorageClasses for the undercloud's volume types. Check
    `kubectl get storageclass` on a fresh cluster first: if the Magnum driver
    already created a default class, either skip this or set
    default_storage_class = null to avoid two defaults.
  EOT
  type        = bool
  default     = false
}

variable "default_storage_class" {
  description = "Name from the storage-classes module to mark as cluster default; null for none."
  type        = string
  default     = "standard"
}

variable "enable_traefik" {
  description = "Traefik ingress controller behind an Octavia LoadBalancer."
  type        = bool
  default     = false
}

variable "ingress_load_balancer_ip" {
  description = "Fixed floating IP for Traefik (see the traefik module). null = Octavia picks one."
  type        = string
  default     = null
}

variable "enable_cnpg" {
  description = "CloudNativePG operator for in-cluster Postgres."
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  type    = bool
  default = false
}

variable "enable_trust_manager" {
  type    = bool
  default = false

  validation {
    condition     = !var.enable_trust_manager || var.enable_cert_manager
    error_message = "trust-manager requires enable_cert_manager = true."
  }
}

variable "enable_jaeger" {
  type    = bool
  default = false
}

variable "enable_jenkins" {
  type    = bool
  default = false
}

variable "enable_harness" {
  type    = bool
  default = false
}

variable "harness_account_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "harness_manager_endpoint" {
  description = "Your account's Harness manager URL (see modules/harness). Required with enable_harness."
  type        = string
  default     = null
}

variable "harness_delegate_token" {
  type      = string
  default   = null
  sensitive = true
}
