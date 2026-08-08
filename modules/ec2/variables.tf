variable "vpc_id" {
  description = "VPC the instance and its security group live in"
  type        = string
}

variable "allowed_cidr" {
  description = "The only CIDR allowed inbound to the app port — expected to be a single /32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_cidr))
    error_message = "allowed_cidr must be a valid IPv4 CIDR, e.g. 203.0.113.4/32."
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
