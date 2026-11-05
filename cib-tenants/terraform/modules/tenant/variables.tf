variable "domain" {
  type = string
}

variable "owner" {
  type = string
}

variable "description" {
  type = string
}

variable "projects" {
  type = map(object({
    description = optional(string)
    quota       = optional(map(number))
  }))
}

variable "persona_role_ids" {
  description = "Persona => { role name => role ID }. One group per persona, roles inherited on the domain."
  type        = map(map(string))

  validation {
    condition     = contains(keys(var.persona_role_ids), "admin")
    error_message = "An \"admin\" persona is required."
  }
}

variable "automation_persona" {
  description = "Persona builder-admin belongs to."
  type        = string
  default     = "developer"
}

variable "users" {
  description = "People in this tenant: username => persona, optional email/description, enabled. null = use default_users."
  type = map(object({
    persona     = string
    email       = optional(string)
    description = optional(string)
    enabled     = optional(bool, true)
  }))
  default = null
}

variable "default_users" {
  type = map(object({
    persona     = string
    email       = optional(string)
    description = optional(string)
    enabled     = optional(bool, true)
  }))
  default = {}
}

variable "platform_admin_id" {
  type    = string
  default = null
}

variable "shared_security_group_ids" {
  description = "Short name => undercloud security group ID to share into every project."
  type        = map(string)
  default     = {}
}

variable "platform_project_id" {
  description = "Admin project that owns state buckets."
  type        = string
}

variable "rgw_project_namespacing" {
  type    = bool
  default = false
}

variable "keystone_url" {
  type = string
}

variable "s3_endpoint" {
  type = string
}

variable "os_cacert_path" {
  type = string
}

variable "github_enabled" {
  type    = bool
  default = false
}

variable "github_repository" {
  type = string
}

variable "github_visibility" {
  type    = string
  default = "private"
}

variable "github_owner" {
  type = string
}

variable "github_template_repository" {
  type = string
}
