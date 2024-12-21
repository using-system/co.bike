resource "azurerm_resource_group" "vnet" {
  location = var.location
  name     = "${module.convention.resource_name}-vnet"

  tags = var.tags
}

resource "azurerm_network_security_group" "vnet" {

  for_each = {
    for subnet in var.vnet_subnets : subnet.name => subnet
    if subnet.name != "GatewaySubnet"
  }

  name                = "${each.key}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.vnet.name


  dynamic "security_rule" {
    for_each = each.value.network_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_address_prefix      = security_rule.value.source_address_prefix
      source_port_range          = security_rule.value.source_port_range
      destination_address_prefix = security_rule.value.destination_address_prefix
      destination_port_range     = security_rule.value.destination_port_range
    }
  }

  tags = var.tags
}

resource "azurerm_route_table" "vnet" {

  for_each = {
    for subnet in var.vnet_subnets : subnet.name => subnet
    if subnet.name != "AzureBastionSubnet"
  }

  name                          = "${each.key}-rt"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.vnet.name
  bgp_route_propagation_enabled = true

  dynamic "route" {
    for_each = each.value.routes
    content {
      name                   = route.value.name
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = route.value.next_hop_in_ip_address
    }
  }

  tags = var.tags

}


locals {
  nsg_ids = {
    for subnet in var.vnet_subnets : subnet.name =>
    try(azurerm_network_security_group.vnet[subnet.name].id, null)
    if subnet.name != "GatewaySubnet"
  }

  enriched_vnet_subnets = {
    for subnet_name, subnet in var.vnet_subnets : subnet_name => merge(
      subnet,
      subnet_name == "GatewaySubnet" ? {
        route_table = {
          id = azurerm_route_table.vnet[subnet_name].id
        }
      } :
      subnet_name == "AzureBastionSubnet" ? {
        network_security_group = {
          id = azurerm_network_security_group.vnet[subnet_name].id
        }
      } :
      {
        network_security_group = {
          id = azurerm_network_security_group.vnet[subnet_name].id
        }
        route_table = {
          id = azurerm_route_table.vnet[subnet_name].id
        }
      }
    )
  }
}

module "vnet" {

  depends_on = [azurerm_network_security_group.vnet]
  source     = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork?ref=a6bb3208c215624bf18fb5066e8c8e381eb037a5"

  address_space       = [var.vnet_address_space]
  location            = var.location
  name                = "cob-vnet"
  resource_group_name = azurerm_resource_group.vnet.name

  subnets = local.enriched_vnet_subnets

  tags = var.tags
}
