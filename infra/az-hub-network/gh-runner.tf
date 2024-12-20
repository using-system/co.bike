locals {
  formatted_github_private_key = format("-----BEGIN RSA PRIVATE KEY-----\n%s\n-----END RSA PRIVATE KEY-----", replace(var.gh_runner_app_private_key, " ", ""))
}

module "gh_runner" {

  source = "git::https://github.com/using-system/devops.git//terraform/modules/az-aca?ref=810612766a5774f901f9b3d4d75bebab3273ac9d"

  name                = "gh-runner"
  resource_group_name = azurerm_resource_group.aca.name

  container_app_environment_id = azurerm_container_app_environment.aca.id

  image        = "myoung34/github-runner:latest"
  cpu          = 0.5
  memory       = "1Gi"
  min_replicas = 2
  max_replicas = 2

  secrets = [
    {
      name  = "app-key"
      value = local.formatted_github_private_key
    }
  ]

  environment_variables = [
    {
      name  = "RUNNER_SCOPE",
      value = "repo"
    },
    {
      name  = "REPO_URL",
      value = "https://github.com/using-system/co.bike"
    },
    {
      name  = "DISABLE_AUTO_UPDATE",
      value = "true"
    },
    {
      name  = "APP_ID",
      value = var.gh_runner_app_id
    },
    {
      name        = "APP_PRIVATE_KEY",
      secret_name = "app-key"
    },
    {
      name  = "LABELS",
      value = "cob,stg-infra,prd-infra,dev-app,prd-app"
    },
    {
      name        = "APP_PRIVATE_KEY",
      secret_name = "app-key"
    }
  ]

  tags = var.tags
}
