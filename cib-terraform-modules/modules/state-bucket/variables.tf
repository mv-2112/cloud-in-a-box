variable "name" {
  description = "Bucket name. Global across the cloud unless RGW project namespacing is on."
  type        = string
}

variable "grant_project_ids" {
  description = "Keystone project IDs given object read/write. Empty = owner only."
  type        = list(string)
  default     = []
}

variable "rgw_project_namespacing" {
  description = <<-EOT
    Matches the MicroCeph charm's `namespace-projects` option (fixed at deploy
    time, default false). false: principal arn:aws:iam:::user/<project_id>.
    true: arn:aws:iam::<project_id>:user/<project_id>, and grantees must address
    the bucket as "<owner_project_id>:<bucket>".
  EOT
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Expire superseded state versions after this many days. null (default) = keep them; the lifecycle API isn't usable with Ceph RGW from Terraform."
  type        = number
  default     = null
}

variable "public_access_block" {
  description = "Add an S3 public access block. Off by default: Ceph RGW can't return it, so Terraform fails reading it back. Use on real S3."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "owner_project_id" {
  description = "Keystone project that owns the bucket. Only needed with rgw_project_namespacing, to build the name grantees must use."
  type        = string
  default     = null
}
