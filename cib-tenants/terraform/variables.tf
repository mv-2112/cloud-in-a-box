variable "github_owner" {
  description = "GitHub org that holds cib-tenant-template and the tenant repos."
  type        = string
}

variable "github_template_repository" {
  type    = string
  default = "cib-tenant-template"
}

variable "s3_endpoint" {
  description = "Public RGW S3 endpoint (state for undercloud, provisioner and tenants)."
  type        = string
}

variable "admin_domain" {
  description = "Sunbeam's admin domain (OS_USER_DOMAIN_NAME in admin_openrc)."
  type        = string
  default     = "admin_domain"
}

variable "admin_project" {
  description = "Sunbeam's admin project (OS_PROJECT_NAME in admin_openrc)."
  type        = string
  default     = "admin"
}

variable "admin_user" {
  description = "Sunbeam's admin user (OS_USERNAME in admin_openrc)."
  type        = string
  default     = "admin"
}

variable "tenants_dir" {
  type    = string
  default = "../tenants"
}

variable "personas" {
  description = <<-EOT
    Generic personas every tenant gets, as persona => Keystone roles. Each
    becomes a group in the tenant's domain with these roles inherited on it.

    - admin:     runs the tenant: manages its users and role assignments
                 (Keystone `manager`) and all resources.
    - developer: builds and changes resources, incl. load balancers. The
                 tenant's automation (builder-admin) is a developer.
    - viewer:    read-only across the tenant's projects.

    Never add `admin`: on Keystone without enforced scope it is cloud-wide
    admin, and Sunbeam's RGW treats it as an RGW admin over every bucket.
  EOT
  type        = map(list(string))
  default = {
    admin     = ["manager", "member", "load-balancer_member"]
    developer = ["member", "load-balancer_member"]
    viewer    = ["reader"]
  }

  validation {
    condition     = alltrue([for roles in values(var.personas) : !contains(roles, "admin")])
    error_message = "No persona may hold the Keystone admin role."
  }

  validation {
    condition     = contains(keys(var.personas), "admin") && contains(keys(var.personas), "developer")
    error_message = "The admin and developer personas are required (developer is the automation persona)."
  }
}

variable "default_users" {
  description = "Generic users created in a tenant whose YAML has no `users:` block."
  type = map(object({
    persona     = string
    email       = optional(string)
    description = optional(string)
    enabled     = optional(bool, true)
  }))
  default = {
    tenant-admin = { persona = "admin", description = "Generic tenant administrator" }
    developer    = { persona = "developer", description = "Generic developer" }
    viewer       = { persona = "viewer", description = "Generic read-only user" }
  }
}

variable "add_platform_admin_to_tenant_groups" {
  description = "Put the cloud `admin` user in every tenant's admin group (old behaviour). It already has cloud-wide admin, so this only adds noise to audits."
  type        = bool
  default     = false
}

variable "os_cacert_path" {
  description = "CA bundle path on the self-hosted runner, written into tenant repos as OS_CACERT_PATH."
  type        = string
  default     = "/etc/ssl/certs/ca-certificates.crt"
}
