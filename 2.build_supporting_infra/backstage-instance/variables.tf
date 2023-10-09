variable "project" { default = "builder" }
variable "image" { default = "ubuntu" }
variable "flavour" { default = "m1.medium" }
variable "externalGateway" { default = "external-network" }
variable "tcp_ports" { default = [ 22,3000, 7007 ]}
variable "domain" {
  type = string
  default = "example.com"
}
variable "expose" { default = false }
