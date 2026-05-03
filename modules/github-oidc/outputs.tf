output "role_arn" {
  description = "ARN of the IAM role — paste this into GitHub Secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider registered in this account"
  value       = aws_iam_openid_connect_provider.github.arn
}
