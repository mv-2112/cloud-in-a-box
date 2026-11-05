variable "name" {
  type    = string
  default = "builder-cluster"
}

variable "kubernetes_version" {
  description = "Must match a template published by cib-undercloud, e.g. v1.35.0"
  type        = string
}

variable "master_count" {
  type    = number
  default = 1
}

variable "node_count" {
  type    = number
  default = 1
}

variable "keypair_name" {
  type    = string
  default = null
}

variable "fixed_network" {
  description = "Network name to place nodes on. Null lets Magnum create one."
  type        = string
  default     = null
}

variable "fixed_subnet" {
  type    = string
  default = null
}

variable "create_timeout" {
  description = "Minutes"
  type        = number
  default     = 60
}

variable "output_dir" {
  description = "Where kubeconfig / helper scripts are written. Defaults to ./config in the root module."
  type        = string
  default     = "./config"
}

variable "kubeconfig_source" {
  description = "magnum = write Magnum's kubeconfig; clusterctl = write a helper script to fetch it from the CAPI management cluster (Sunbeam host only)."
  type        = string
  default     = "magnum"

  validation {
    condition     = contains(["magnum", "clusterctl"], var.kubeconfig_source)
    error_message = "kubeconfig_source must be \"magnum\" or \"clusterctl\"."
  }
}
