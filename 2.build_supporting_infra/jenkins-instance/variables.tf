variable "project" { default = "playground" }
variable "image" { default = "Debian-10" }
variable "flavour" { default = "m1.medium" }
variable "externalGateway" { default = "external-network" }
variable "domain" {
  type = string
  default = "local"
}
variable "lb_floating_ip" { default = "" }