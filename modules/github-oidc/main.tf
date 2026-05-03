# Register GitHub as a trusted identity provider in this AWS account.
# This tells AWS: "tokens signed by token.actions.githubusercontent.com are valid."
# Only needs to exist once per account — Terraform handles idempotency.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # sts.amazonaws.com is the audience GitHub sends in its tokens.
  # AWS validates this matches before issuing credentials.
  client_id_list = ["sts.amazonaws.com"]

  # SHA-1 thumbprint of GitHub's OIDC TLS certificate.
  # AWS uses this to verify it's actually talking to GitHub's endpoint.
  # This value is stable — GitHub publishes it and rotates it rarely.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# The IAM role that GitHub Actions will assume during workflow runs.
# The trust policy defines *who* can assume it and under *what conditions*.
resource "aws_iam_role" "github_actions" {
  name        = var.role_name
  description = "Assumed by GitHub Actions via OIDC no static credentials"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # The OIDC provider ARN — not GitHub directly.
          # AWS checks the token against this provider's public keys.
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # "aud" claim must match — prevents tokens issued for other services from working here
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # "sub" claim identifies the specific repo and context.
            # The wildcard (*) allows any branch or PR in this repo to assume the role.
            # For production apply, tighten this to ":ref:refs/heads/main" only.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Attach ReadOnlyAccess for describing AWS resources during terraform plan.
# Covers EC2 Describe*, IAM Get*/List*, S3 GetObject — everything plan needs to read.
resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Inline policy for S3 state lock management.
# terraform plan acquires a lock (PutObject .tflock) and releases it (DeleteObject) even for read-only runs.
# ReadOnlyAccess doesn't include PutObject — this targeted policy adds only what's needed.
# Scoped to the exact state bucket — not all S3.
resource "aws_iam_role_policy" "state_lock" {
  name = "terraform-state-lock"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",    # acquire lock — write .tflock file
          "s3:DeleteObject", # release lock — delete .tflock file
          "s3:GetObject",    # read state file (belt-and-suspenders over ReadOnlyAccess)
        ]
        Resource = "arn:aws:s3:::tfstate-060451241527-us-east-1-an/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::tfstate-060451241527-us-east-1-an"
      }
    ]
  })
}
