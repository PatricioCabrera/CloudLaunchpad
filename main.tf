module "networking" {
  source = "./modules/networking"
  subnets = {
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
  vpc_cidr = "10.0.0.0/21"
}
