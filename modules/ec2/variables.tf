variable "vpc_id" {
  description = "VPC the instance and its security group live in"
  type        = string
}

variable "allowed_cidr" {
  description = "The only CIDR allowed inbound to the app port — expected to be a single /32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_cidr))
    error_message = "allowed_cidr must be a valid IPv4 CIDR, e.g. 203.0.113.4/32. An IPv6 address here means the IP-echo service answered over AAAA — use an IPv4-only endpoint."
  }
}

variable "app_port" {
  description = "Port uvicorn binds on the instance"
  type        = number
  default     = 8000
}

variable "subnet_id" {
  description = "Subnet the instance launches into — must be public, the operator reaches the app over its public IP"
  type        = string
}

# Coupled to the AMI architecture in main.tf. Changing this to an x86_64 type
# without changing the SSM parameter path there produces an instance that will
# not boot the image.
variable "instance_type" {
  description = "Instance type — arm64, to match the Graviton AMI"
  type        = string
  default     = "t4g.micro"
}

# Cloned anonymously over HTTPS: the instance holds no GitHub credential, so
# this only works while the repo is public. A private repo would need a deploy
# key or a PAT out of Secrets Manager — which is a Block 3 problem.
variable "app_repo_url" {
  description = "HTTPS clone URL of the application repository"
  type        = string
  default     = "https://github.com/PatricioCabrera/CloudLaunchpad.git"
}

variable "app_repo_branch" {
  description = "Branch cloud-init clones — the app must already be merged here, not sitting on a feature branch"
  type        = string
  default     = "main"
}
