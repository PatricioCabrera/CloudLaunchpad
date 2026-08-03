provider "aws" {
  region = var.aws_region
  # No profile specified — uses the standard credential chain:
  # 1. Environment variables (CI: injected by OIDC action)
  # 2. ~/.aws/config named profile (local: your SSO session)
}
