variable "project" { default = "playground" }
variable "image" { default = "Debian-10" }
variable "flavour" { default = "m1.medium" }
variable "number_to_build" { default = 1 }
variable "domain" {
  type    = string
  default = "example.com"
}
variable "expose_node" { default = false }
variable "expose_lb" { default = false }
variable "external_network" { default = "external-network" }
