variable "name" {
  description = "VM name; also the runner's name in GitHub and the prefix for its network objects."
  type        = string
}

variable "github_repository_url" {
  description = "https://github.com/<owner>/<repo> the runner registers to."
  type        = string
}

variable "registration_token" {
  description = "Repo registration token (data.github_actions_registration_token). Valid one hour; read on first boot only."
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Extra labels on top of self-hosted/Linux/X64. Workflows target these."
  type        = list(string)
}

variable "runner_version" {
  description = "Starting version; the runner self-updates after registering."
  type        = string
  default     = "2.338.2"
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "flavor" {
  type    = string
  default = "m1.small"
}

variable "disk_gb" {
  type    = number
  default = 30
}

variable "external_network" {
  type    = string
  default = "external-network"
}

variable "cidr" {
  type    = string
  default = "10.250.0.0/24"
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "ca_cert_pem" {
  description = "Cloud CA to trust (Sunbeam self-signed TLS). null = system CAs only."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "ssh_allowed_cidrs" {
  description = "Sources allowed to SSH in, IPv4 and/or IPv6 CIDRs. Empty = no inbound at all."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "ipv6_enabled" {
  description = "Give the runner a routed IPv6 /64 from the platform's tenant pool. Required if management/APIs are IPv6."
  type        = bool
  default     = true
}

variable "ipv6_subnetpool" {
  type    = string
  default = "cib-tenant-v6"
}
