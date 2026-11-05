# Private, versioned Terraform state bucket on Ceph RGW.
#
# The bucket is owned by whoever the calling `aws` provider authenticates as
# (the platform admin project). Access for anyone else is granted only through
# the bucket policy below, scoped to object read/write. Grantees can't change
# the policy, make the bucket public, turn off versioning or delete the bucket.
#
# RGW with Keystone (Sunbeam/MicroCeph) maps each Keystone *project* to an RGW
# user, so grants are per project. See var.rgw_project_namespacing for the
# principal format.

terraform {
  required_version = ">= 1.5" # check blocks

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

locals {
  principals = [
    for p in var.grant_project_ids :
    var.rgw_project_namespacing ? "arn:aws:iam::${p}:user/${p}" : "arn:aws:iam:::user/${p}"
  ]
}

check "namespacing_needs_owner" {
  assert {
    condition     = !var.rgw_project_namespacing || var.owner_project_id != null
    error_message = "owner_project_id is required when rgw_project_namespacing = true."
  }
}

resource "aws_s3_bucket" "this" {
  bucket = var.name

  # State is not disposable. Deleting a bucket that still holds state needs a
  # deliberate change to this flag first.
  force_destroy = false

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Off by default: Ceph RGW accepts PutPublicAccessBlock but can't return it,
# so the provider fails reading it back ("couldn't find resource"). The bucket
# is private regardless: no ACL grants, and grantees get object access only
# through the policy below, so they can't make it public themselves.
resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.public_access_block ? 1 : 0
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire old state versions. Off by default: after setting the rule the aws
# provider waits for RGW to report the identical rule back, which RGW doesn't,
# so it times out. Old versions are small; prune them manually if needed.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.noncurrent_version_days != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "this" {
  count = length(local.principals) > 0 ? 1 : 0

  statement {
    sid       = "TenantList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.this.id}"]

    principals {
      type        = "AWS"
      identifiers = local.principals
    }
  }

  statement {
    sid       = "TenantObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.this.id}/*"]

    principals {
      type        = "AWS"
      identifiers = local.principals
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count  = length(local.principals) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
