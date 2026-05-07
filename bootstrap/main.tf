provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Logging requires a second destination bucket — circular for bootstrap infra.
# State access is controlled via IAM, not S3 access logs.
#trivy:ignore:AVD-AWS-0089  # S3 access logging disabled intentionally.
resource "aws_s3_bucket" "tfstate" {
  bucket           = format("tfstate-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"
  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls = true
  ignore_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
}

# SSE-S3 encryption at rest — AWS-managed keys.
# SSE-S3 provides encryption at rest. CMK adds ~$1/key/month + operational overhead
#trivy:ignore:AVD-AWS-0132  # CMK (customer-managed KMS key) not used intentionally.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3, not SSE-KMS — no CMK required
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}
