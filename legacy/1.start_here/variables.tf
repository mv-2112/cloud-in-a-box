# Set this to form the prefix for the tenant/domain
variable "domain" {
  type    = string
  default = "example.com"
}

variable "external_network" {
  type    = string
  default = "external-network"
}


variable "dns_server" {
  type    = list
  default = [ "192.168.68.1" ]
}


# Set this to form the prefix for the build project
variable "build_project" { default = "builder" }


# This provides the list for the roles data array
variable "roles" { default = ["member", "Admin", "reader", "service", ] }


# Set this to form the prefix for the build project
variable "app_projects" { default = ["app0", "app1", "app2", "app3"] }

variable "users" {
  default = {
    "app0" = {
      "app0-admin" = {
        role   = "admin"
        groups = "app0-admins"
      }
      "verranm" = {
        role   = "member"
        groups = "app0-users"
      }
    }
    "app1" = {
      "app1-admin" = {
        role   = "admin"
        groups = "app1-admins"
      }
    }
    "app2" = {
      "app2-admin" = {
        role   = "admin"
        groups = "app2-admins"
      }
    }
    "app3" = {
      "app3-admin" = {
        role   = "admin"
        groups = "app3-admins"
      }
    }
  }
}


variable "groups" {
  default = {
    "app0" = {
      "app0-admins" = {
        description = "Admins"
        role        = "Admin"
      }
      "app0-users" = {
        description = "Regular user group"
        role        = "member"
      }
    }
    "app1" = {
      "app1-admins" = {
        description = "Admins"
        role        = "Admin"
      }
    }
    "app2" = {
      "app2-admins" = {
        description = "Admins"
        role        = "Admin"
      }
    }
    "app3" = {
      "app3-admins" = {
        description = "Admins"
        role        = "Admin"
      }
    }
  }
}