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

variable "enable_ec2" {
  description = "Toggle the standalone EC2 instance (Block 2 — deliberately replaced by ECS Fargate in Block 3). Defaults off: CI applies on merge to main, and an instance nobody opted into survives the session."
  type        = bool
  default     = false
}

variable "subnets" {
  description = "Subnets carved from the VPC range: newbits is added to its prefix length, netnum picks which block of that size, public decides the route"
  type = map(object({
    newbits = number
    netnum  = number
    public  = bool
  }))
  # In a /21: public /27s share the first /24; private /24s take the next two.
  default = {
    "public-a"  = { newbits = 6, netnum = 0, public = true }
    "public-b"  = { newbits = 6, netnum = 1, public = true }
    "private-a" = { newbits = 3, netnum = 1, public = false }
    "private-b" = { newbits = 3, netnum = 2, public = false }
  }
}
