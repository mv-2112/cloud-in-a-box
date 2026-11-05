variable "state_bucket" {
  type = string
}

variable "s3_endpoint" {
  type = string
}

variable "harness_account_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "harness_manager_endpoint" {
  description = "Your account's Harness manager URL, e.g. https://app.harness.io (Account Settings > Account Overview)."
  type        = string
  default     = null
}

variable "harness_delegate_token" {
  type      = string
  default   = null
  sensitive = true
}
