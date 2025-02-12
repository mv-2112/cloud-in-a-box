# Set this to form the prefix for the build project
variable "builder_project" { default = "builder" }


variable "domain" {
  type    = string
  default = "example.com"
}


variable "dns_servers" {
  type    = list
  default = ["8.8.8.8", "8.8.4.4"]
}


variable "external_network" {
  type    = string
  default = "external-network"
}


variable "cluster_template" {
  type    = string
  default = "616a3285-fcc9-4cbb-babf-fce7577a9f7a"
}
