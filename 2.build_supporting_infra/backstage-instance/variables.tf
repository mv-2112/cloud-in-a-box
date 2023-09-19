variable "project" { default = "playground" }
variable "image" { default = "Debian-10" }
variable "flavour" { default = "m1.medium" }
variable "externalGateway" { default = "external-network" }
variable "tcp_ports" { default = [ 22,3000, 7007 ]}
variable "domain" {
  type = string
  default = "local"
}
variable "expose" { default = false }
