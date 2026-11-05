variable "domain" {
  description = "Tenant domain. Set by the pipeline from the TENANT_DOMAIN repo variable."
  type        = string
}

variable "kubernetes_version" {
  description = "Must be a version published by cib-undercloud."
  type        = string
  default     = "v1.35.0"
}

variable "enable_cluster" {
  type    = bool
  default = true
}

variable "node_count" {
  type    = number
  default = 1
}

variable "enable_ipv6" {
  description = "Dual-stack: add a routed IPv6 /64 (ULA, from the platform's tenant pool) to the tenant network."
  type        = bool
  default     = true
}
