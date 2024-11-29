variable "sites" {
  type = map(object({
    owner = string
    description = string

  }))

  default = {
    "www.example1.com" = {
      owner    = "Alice"
      description    = "www.example1.com"
    }
    "www.example2.com" = {
      owner    = "Bob"
      description    = "www.example2.com"
    }
  }
}


variable "external_network" {
  type    = string
  default = "external-network"
}

variable "dns_servers" {
  type    = list
  default = ["8.8.8.8", "8.8.4.4"]
}


variable "default_coreos_image" {
  type = string
  default = "38.20230806.3.0"
}