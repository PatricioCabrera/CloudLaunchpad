variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub org or user that owns this repository, for the OIDC trust policy"
  type        = string
  default     = "PatricioCabrera"
}

variable "github_repo" {
  description = "GitHub repository name, for the OIDC trust policy"
  type        = string
  default     = "CloudLaunchpad"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/21"
}

variable "subnets" {
  description = "Subnets to create: CIDR block and public/private per subnet"
  type = map(object({
    cidr   = string
    public = bool
  }))
  default = {
    "public-a" = {
      cidr   = "10.0.0.0/27"
      public = true
    }
    "public-b" = {
      cidr   = "10.0.0.32/27"
      public = true
    }
    "private-a" = {
      cidr   = "10.0.1.0/24"
      public = false
    }
    "private-b" = {
      cidr   = "10.0.2.0/24"
      public = false
    }
  }
}
