output "bucket" {
  value = aws_s3_bucket.this.id
}

output "principals" {
  description = "RGW principals granted access (useful when debugging a 403)."
  value       = local.principals
}

output "grantee_bucket_name" {
  description = "Bucket name as grantees must address it (tenant-qualified when RGW project namespacing is on)."
  value       = var.rgw_project_namespacing ? "${var.owner_project_id}:${aws_s3_bucket.this.id}" : aws_s3_bucket.this.id
}
