variable "istio_helm_version" {
  description = "Istio Helm chart version"
  type        = string
}

variable "mode" {
  description = "Istio mode: classic or ambient"
  type        = string
  default     = "classic"

  validation {
    condition     = contains(["classic", "ambient"], var.mode)
    error_message = "mode must be 'classic' or 'ambient'"
  }
}

variable "istio_version" {
  description = "Istio version"
  type        = string
  default     = "default"
}

variable "namespace" {
  type    = string
  default = "istio-system"
}

variable "ingress_namespace" {
  type    = string
  default = "istio-ingress"
}

variable "egress_namespace" {
  type    = string
  default = "istio-egress"
}

variable "enable_ingress" {
  type    = bool
  default = true
}

variable "enable_egress" {
  type    = bool
  default = false
}

variable "enable_cni" {
  description = "Override CNI enablement"
  type        = bool
  default     = null
}

variable "istiod_values" {
  type    = list(any)
  default = []
}

variable "gateway_values" {
  type    = list(any)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}