module "bootstrap" {
  source = "../../modules/bootstrap"

  project                     = var.project
  github_repository           = var.github_repository
  github_apply_environment    = var.github_apply_environment
  create_github_oidc_provider = var.create_github_oidc_provider
}
