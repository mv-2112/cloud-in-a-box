variable "project" { default = "users" }
variable "image" { default = "ubuntu" }
variable "flavour" { default = "m1.medium" }
variable "gke_master_number_to_build" { default = 1 }
variable "gke_node_number_to_build" { default = 1 }
variable "domain" {
  type = string
  default = "local"
}
  type = string
  default = ["local"]
}
variable "expose" { default = false }