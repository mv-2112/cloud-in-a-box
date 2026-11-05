variable "account_id" {
  description = "Harness account ID (Account Settings > Account Overview)."
  type        = string
  sensitive   = true
}

variable "delegate_token" {
  description = "Delegate token (Account/Project Settings > Delegates > Tokens)."
  type        = string
  sensitive   = true
}

variable "manager_endpoint" {
  description = <<-EOT
    Your account's Harness manager URL. It depends on the cluster your account
    is on (Account Settings > Account Overview > Harness Cluster Location),
    e.g. https://app.harness.io or https://app3.harness.io/gratis. The install
    command Harness shows for a new delegate has the right value.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://", var.manager_endpoint))
    error_message = "manager_endpoint must be your account's Harness URL, e.g. https://app.harness.io (set harness_manager_endpoint)."
  }
}

variable "delegate_name" {
  type    = string
  default = "terraform-delegate"
}

variable "namespace" {
  type    = string
  default = "harness-delegate-ng"
}

variable "delegate_image" {
  description = "Delegate image. Take the current tag from the install command Harness shows (the upgrader keeps it current afterwards)."
  type        = string
  default     = "us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:26.01.88303"
}

variable "replicas" {
  type    = number
  default = 1
}

variable "upgrader_enabled" {
  description = "Let Harness's upgrader keep the delegate image current."
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "harness-delegate-ng chart version; null = latest (`helm search repo harness-delegate` lists them)."
  type        = string
  default     = null
}

variable "extra_values" {
  description = "Extra chart values as YAML (like helm -f), merged after the ones above."
  type        = string
  default     = ""
}
