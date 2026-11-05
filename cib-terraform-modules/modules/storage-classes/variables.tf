variable "storage_classes" {
  description = "StorageClass name => Cinder volume type (must exist in cib-undercloud)."
  type = map(object({
    volume_type    = string
    reclaim_policy = optional(string, "Delete")
  }))
  default = {
    standard    = { volume_type = "standard" }
    multiattach = { volume_type = "multiattach" }
  }
}

variable "default_class" {
  description = <<-EOT
    Cluster default StorageClass. The old module defaulted to multiattach;
    attaching one volume to several nodes is only safe with a cluster-aware
    filesystem, so ordinary PVCs should land on standard.
  EOT
  type        = string
  default     = "standard"

  validation {
    condition     = var.default_class == null || contains(keys(var.storage_classes), coalesce(var.default_class, "-"))
    error_message = "default_class must be one of the keys in storage_classes, or null for no default."
  }
}

variable "availability_zone" {
  type    = string
  default = "nova"
}
