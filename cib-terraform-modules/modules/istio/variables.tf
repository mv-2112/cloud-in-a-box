variable "istio_version" {
  description = "Istio version to install (e.g., '1.20.0')"
  type        = string
  default     = "1.20.0"
}

variable "enable_ambient" {
  description = "Enable Istio ambient mode (zero-sidecar)"
  type        = bool
  default     = false
}

variable "istio_namespace" {
  description = "Namespace for Istio components"
  type        = string
  default     = "istio-system"
}

variable "istio_base_values" {
  description = "Custom Helm values for istio-base chart (YAML format)"
  type        = string
  default     = ""
}

variable "istiod_values" {
  description = "Custom Helm values for istiod chart (YAML format)"
  type        = string
  default     = ""
}

variable "gateway_values" {
  description = "Custom Helm values for gateway chart (YAML format)"
  type        = string
  default     = ""
}

variable "enable_gateway" {
  description = "Deploy Istio ingress gateway"
  type        = bool
  default     = true
}