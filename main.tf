module "github_oidc" {
  source      = "./modules/github-oidc"
  github_org  = var.github_org
  github_repo = var.github_repo
}

module "networking" {
  source   = "./modules/networking"
  subnets  = var.subnets
  vpc_cidr = var.vpc_cidr
}

# Resolved at plan time, so the security group follows the operator's current
# address. Lives at root rather than inside the module: a module that phones an
# external service on every plan is not reusable from CI, where the runner's
# public IP means nothing.
data "http" "my_ip" {
  count = var.enable_ec2 ? 1 : 0
  url   = "https://ifconfig.me/ip"
}

module "ec2" {
  count  = var.enable_ec2 ? 1 : 0
  source = "./modules/ec2"

  vpc_id       = module.networking.vpc_id
  subnet_id    = module.networking.subnet_ids["public-a"]
  allowed_cidr = "${chomp(data.http.my_ip[0].response_body)}/32"
}
