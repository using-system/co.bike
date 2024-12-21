module "convention" {
  source = "../modules/convention"

  project     = "cob"
  environment = var.env
  region      = var.location_short_name
}
