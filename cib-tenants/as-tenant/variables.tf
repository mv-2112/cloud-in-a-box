variable "domain" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "repository" {
  description = "The tenant's repo: receives the pipeline credential, and is the only repo the runner serves."
  type        = string
}

variable "pipeline_roles" {
  description = "Roles on the pipeline credential. Keep `member` (RGW and most services need it); never `admin` or `manager`."
  type        = list(string)
  default     = ["member", "load-balancer_member"]

  validation {
    condition     = length(setintersection(var.pipeline_roles, ["admin", "manager"])) == 0
    error_message = "The pipeline credential must not carry admin or manager."
  }
}

variable "pipeline_unrestricted" {
  description = "Required for Magnum cluster builds (trusts). Set false if the tenant never builds clusters."
  type        = bool
  default     = true
}

variable "credential_rotation_days" {
  type    = number
  default = 30
}

variable "credential_grace_days" {
  description = "Extra validity after rotation, for jobs already running."
  type        = number
  default     = 7
}

variable "runner_enabled" {
  type    = bool
  default = false
}

variable "runner_labels" {
  type    = list(string)
  default = ["cib-tenant"]
}

variable "runner_flavor" {
  type    = string
  default = "m1.small"
}

variable "runner_disk_gb" {
  type    = number
  default = 30
}

variable "runner_cidr" {
  description = "Runner's own network; keep clear of the tenant's subnets."
  type        = string
  default     = "10.251.0.0/24"
}

variable "ca_cert_pem" {
  type    = string
  default = null
}
