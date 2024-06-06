# Set this to form the prefix for the tenant/domain
variable "domain" {
  type    = string
  default = "example.com"
}

# Set this to form the prefix for the build project
variable "build_project" { default = "builder" }

variable "github_pat" {
  type      = string
  sensitive = true
}

variable "auth_github_client_id" {
  type      = string
  sensitive = true
}

variable "auth_github_client_secret" {
  type      = string
  sensitive = true
}

variable "build_applications" {
  type = map(object({
    name = string
    ports = map(object({
      description = string
      port_number = number
      protocol    = string
    }))
    enable = bool
  }))
  default = {
    jenkins = {
      name = "jenkins"
      ports = {
        http = {
          port_number = 8080
          description = "http"
          protocol    = "tcp"
        }
      }
      enable = false
    }
    backstage = {
      name = "backstage"
      ports = {
        http = {
          port_number = 3000
          description = "frontend"
          protocol    = "tcp"
        }
        backend = {
          port_number = 7007
          description = "backend"
          protocol    = "tcp"
        }
      }
      enable = false
    }
  }
}

