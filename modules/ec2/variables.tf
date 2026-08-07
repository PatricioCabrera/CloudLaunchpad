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
