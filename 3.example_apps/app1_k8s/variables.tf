# Set this to form the prefix for the build project
variable "app_project" { default = "app1" }


# Set this to the ip address of designate-bind
variable "domain" {
  type = string
  default = "example.com"
}

variable "default_image" {
  type = string
  default = "fedora-coreos-38"
}


variable "dns_server" {
  type = string
  default = "8.8.8.8"
}


variable "external_network" {
  type = string
  default = "external-network"
}

variable "kube_release" {
  type = string
  default = "1.28.11"
}
