variable "vpc_cidr" {
  type        = string
  description = "cidr for main vpc"
  default     = "10.0.0.0/21"
}

variable "subnets" {
  type = map(object({
    cidr   = string
    public = bool
  }))
  description = "object containing subnets CIDR and private/public option"
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
