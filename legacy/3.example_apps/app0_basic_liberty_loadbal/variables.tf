# Set this to form the prefix for the build project
variable "app_project" { default = "app0" }

# Set this to the ip address of designate-bind
# variable "dns_server" {
#   type = list
#   default = ["10.0.3.131"]
#}

# Set this to the ip address of designate-bind
variable "domain" {
  type = string
  default = "example.com"
}

variable "default_image" {
  type = string
  default = "ubuntu"
}

variable "external_network" {
  type = string
  default = "external-network"
}
