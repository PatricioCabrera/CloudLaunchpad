terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "tfstate-060451241527-us-east-1-an"
    region = "us-east-1"
    key    = "networking/terraform.tfstate"
    use_lockfile = true
    encrypt = true
  }
}
