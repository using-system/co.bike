data "azurerm_client_config" "current" {

}

data "azuread_group" "admin_group" {
  display_name     = "COB_ADMIN"
  security_enabled = true
}

data "azurerm_subnet" "resources" {
  name                 = "ResourcesSubnet"
  virtual_network_name = local.spoke_vnet_name
  resource_group_name  = "${module.convention.resource_name}-vnet"
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "${module.convention.resource_name}-vnet"
}
