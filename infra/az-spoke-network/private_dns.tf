resource "azurerm_private_dns_zone" "azmk8s" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.vnet.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "azmk8s" {

  depends_on = [azurerm_private_dns_zone.azmk8s]

  name                = module.vnet.vnet_name
  resource_group_name = azurerm_resource_group.vnet.name

  private_dns_zone_name = "privatelink.${var.location}.azmk8s.io"
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone" "vaultcore" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.vnet.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vaultcore" {

  depends_on = [azurerm_private_dns_zone.vaultcore]

  name                = module.vnet.vnet_name
  resource_group_name = azurerm_resource_group.vnet.name

  private_dns_zone_name = "privatelink.vaultcore.azure.net"
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.vnet.name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {

  depends_on = [azurerm_private_dns_zone.blob]

  name                = module.vnet.vnet_name
  resource_group_name = azurerm_resource_group.vnet.name

  private_dns_zone_name = "privatelink.blob.core.windows.net"
  virtual_network_id    = module.vnet.vnet_id
  registration_enabled  = false

  tags = var.tags
}
