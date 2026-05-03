variable "github_org" {
  description = "GitHub username or organization that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}

variable "role_name" {
  description = "Name for the IAM role GitHub Actions will assume"
  type        = string
  default     = "github-actions-terraform"
}
