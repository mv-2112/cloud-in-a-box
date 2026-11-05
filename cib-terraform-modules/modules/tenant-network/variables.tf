variable "name_prefix" {
  description = "Prefix for resource names, usually the tenant domain (dots become underscores)."
  type        = string
}

variable "external_network" {
  type    = string
  default = "external-network"
}

variable "subnets" {
  description = "Subnet purpose => CIDR"
  type        = map(string)
  default = {
    builder     = "10.0.99.0/24"
    application = "10.0.100.0/24"
  }
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "create_keypair" {
  type    = bool
  default = true
}

variable "public_key" {
  description = "Existing public key to register. Leave null to have Nova generate one (private key then ends up in state)."
  type        = string
  default     = null
}

variable "ipv6_enabled" {
  description = "Add a routed IPv6 /64 from the platform's tenant pool. Needs the undercloud's tenant IPv6 (TENANT_V6_POOL)."
  type        = bool
  default     = true
}

variable "ipv6_subnetpool" {
  description = "Subnet pool to carve the /64 from (created by cib-undercloud)."
  type        = string
  default     = "cib-tenant-v6"
}
