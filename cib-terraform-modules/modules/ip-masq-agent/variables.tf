variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "image" {
  type    = string
  default = "registry.k8s.io/networking/ip-masq-agent"
}

variable "image_tag" {
  description = "Newest tag promoted to registry.k8s.io as of Oct 2026 (later git tags were never published)."
  type        = string
  default     = "v2.12.0"
}

variable "nonmasquerade_cidrs" {
  description = "Destinations NOT to masquerade (pod/node/service CIDRs, tenant subnets). Empty = agent defaults (RFC 1918)."
  type        = list(string)
  default     = []
}

variable "masq_link_local" {
  type    = bool
  default = false
}

variable "resync_interval" {
  type    = string
  default = "60s"
}
