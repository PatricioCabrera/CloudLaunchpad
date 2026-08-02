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
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Deny any request not using TLS. Defense in depth rather than a fix:
# the backend, CLI, and console all use HTTPS already, so nothing reaches
# this bucket over plaintext today. Safe alongside block_public_policy —
# S3 only treats *Allow* statements with a wildcard principal as public.
data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    # Both ARNs are required — the bucket for bucket-level calls,
    # the /* for object-level ones. Covering only one is a silent gap.
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json

  # Without this, ordering is not deterministic and a policy applied while
  # the access block is still settling can be rejected.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# SSE-S3 encryption at rest — AWS-managed keys.
# SSE-S3 provides encryption at rest. CMK adds ~$1/key/month + operational overhead
#trivy:ignore:AVD-AWS-0132  # CMK (customer-managed KMS key) not used intentionally.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3, not SSE-KMS — no CMK required
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "Expire old versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 60
    }
  }

  rule {
    id     = "clean-up-markers"
    status = "Enabled"
    filter {}
    expiration {
      expired_object_delete_marker = true
    }
  }
}
