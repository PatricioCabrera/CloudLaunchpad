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

module "budget" {
  source             = "./modules/budget"
  notification_email = var.notification_email
}

# Resolved at plan time, so the security group follows the operator's current
# address. Lives at root rather than inside the module: a module that phones an
# external service on every plan is not reusable from CI, where the runner's
# public IP means nothing.
data "http" "my_ip" {
  count = var.enable_ec2 ? 1 : 0

  # IPv4-only on purpose. Dual-stack echo services answer over AAAA when the
  # connection prefers IPv6 and report the v6 address, which is useless here:
  # the VPC has no IPv6 CIDR, so the instance is reachable only over IPv4 and
  # the source address AWS sees will be this v4 one. checkip.amazonaws.com
  # publishes no AAAA record, so the answer is always the right family.
  url = "https://checkip.amazonaws.com"
}

module "ec2" {
  count  = var.enable_ec2 ? 1 : 0
  source = "./modules/ec2"

  vpc_id       = module.networking.vpc_id
  subnet_id    = module.networking.subnet_ids["public-a"]
  allowed_cidr = "${chomp(data.http.my_ip[0].response_body)}/32"
}
