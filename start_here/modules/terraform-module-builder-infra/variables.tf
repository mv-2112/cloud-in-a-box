variable "external_network" {
  type    = string
  default = "external-network"
}

# Set this to form the prefix for the build project
variable "builder_project" { default = "builder" }

variable "dns_servers" {
  type    = list(any)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "builder_subnet_cidr" {
  type    = string
  default = "10.0.99.0/24"
}

variable "application_subnet_cidr" {
  type    = string
  default = "10.0.100.0/24"
}

variable "k8s_template" {
  type    = string
  default = "v1.27.8-rancher2"
}

variable "domain" {
  type    = string
  default = "didnotset.com"
}

variable "enable_jenkins" {
  type    = bool
  default = false
}


variable "enable_istio" {
  type    = bool
  default = true
}

variable "enable_istio_ambient" {
  type    = bool
  default = true
}

variable "enable_ip_masq" {
  type    = bool
  default = true
}

variable "enable_harness" {
  type    = bool
  default = true
}

variable "harness_account_id" {
  type    = string
  # default = "something like 5gdsgGdgfr53W98wB"
}

variable "harness_delegate_token" {
  type    = string
  # default = "something like ER23tE4Rwyq3QQyb546QOWU3OTllODM0MDhmZjY="
}

variable "enable_cert_manager" {
  type    = bool
  default = true
}

variable "enable_trust_manager" {
  type    = bool
  default = true
}

variable "enable_jaeger" {
  type    = bool
  default = true
}
