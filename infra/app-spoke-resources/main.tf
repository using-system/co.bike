locals {
  k8s_namespace = "${var.project_name}-${var.env}"
}

module "convention" {
  source = "../modules/az-convention"

  project     = var.project_name
  environment = var.env
  region      = var.location_short_name
}

resource "azurerm_resource_group" "app" {
  location = var.location
  name     = "${module.convention.resource_name}-app"

  tags = var.tags
}
