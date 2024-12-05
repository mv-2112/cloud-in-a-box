# Set this to form the prefix for the build project
variable "app_project" { default = "admin" }


variable "domain" {
  type    = string
  default = "admin_domain"
}

variable "default_image" {
  type    = string
  default = "fedora-coreos-38"
}


variable "dns_server" {
  type    = string
  default = "8.8.8.8"
}


variable "external_network" {
  type    = string
  default = "external-network"
}

variable "kube_release" {
  type    = string
  default = "v1.28.9-rancher1"
}

variable "k8s-staging-provider-os" {
  type = string
  default = "v1.24.6"
}
