provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket           = format("tfstate-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"
  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}
