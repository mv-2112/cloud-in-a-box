# Set this to form the prefix for the tenant/domain
variable "domain" {
  type = string
  default = "example.com"
}

# Set this to form the prefix for the build project
variable "build_project" { default = "builder" }
