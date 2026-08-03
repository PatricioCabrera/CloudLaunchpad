data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
            # "sub" claim identifies the specific repo and context. Scoped to exactly
            # the two events the workflow triggers on — a PR run (read-only plan) or
            # a push to main (apply, since branch protection gates what reaches main).
            # No other branch or context can assume this role.
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:pull_request",
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
            ]
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

# Write permissions for the `networking` module: VPC, subnets, routing, flow logs.
# EC2 write actions don't support resource-level ARN scoping — AWS requires
# Resource = "*" here, unlike IAM and CloudWatch Logs below. Grown per module as
# new resource types are introduced, not granted ahead of what's actually deployed.
resource "aws_iam_role_policy" "networking_write" {
  name = "networking-write"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation",
          "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs",
          "ec2:CreateTags", "ec2:DeleteTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
          "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource",
        ]
        # Matches the flow-logs log group naming pattern from the networking module:
        # "/vpc/${var.vpc_cidr}/flow-logs" — scoped to the /vpc/ prefix, not all log groups.
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/vpc/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:TagRole", "iam:UntagRole",
        ]
        # The flow-logs service role the networking module creates — fixed name,
        # not this CI role, so this is not self-modifying access.
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vpc-flow-logs-role"
      }
    ]
  })
}

# Self-management: this PR's own trust-policy tightening needs to apply via CI too,
# once merged. Scoped to exactly this role and this OIDC provider — not IAM broadly.
resource "aws_iam_role_policy" "self_manage" {
  name = "oidc-self-manage"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
        ]
        Resource = aws_iam_role.github_actions.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
        ]
        Resource = aws_iam_openid_connect_provider.github.arn
      }
    ]
  })
}
