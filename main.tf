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
