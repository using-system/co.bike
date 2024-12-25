resource "azurerm_resource_group" "dns" {
  location = var.location
  name     = "${module.convention.resource_name}-dns"

  tags = var.tags
}

resource "azurerm_dns_zone" "dns" {
  name                = "co.bike"
  resource_group_name = azurerm_resource_group.dns.name
}