#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------

env = "stg"

tags = {
  project       = "cob"
  env           = "stg"
  provisionedby = "terraform"
}

#------------------------------------------------------------------------------
# NETWORKING
#------------------------------------------------------------------------------

vnet_address_space = "10.0.0.0/16"
vnet_subnets = {
  "GatewaySubnet" = {
    name              = "GatewaySubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    address_prefixes  = ["10.0.0.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "FirewallSubnet" = {
    name              = "FirewallSubnet"
    service_endpoints = []
    address_prefixes  = ["10.0.1.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "PeeringSubnet" = {
    name              = "PeeringSubnet"
    service_endpoints = []
    address_prefixes  = ["10.0.2.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "ResourcesSubnet" = {
    name              = "ResourcesSubnet"
    service_endpoints = []
    address_prefixes  = ["10.0.3.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "JumpboxSubnet" = {
    name              = "JumpboxSubnet"
    service_endpoints = ["Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    address_prefixes  = ["10.0.4.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "AcaSubnet" = {
    name              = "AcaSubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    address_prefixes  = ["10.0.6.0/23"]
    network_rules = [
    ]
    routes = [
    ]
  }
  "AzureBastionSubnet" = {
    name              = "AzureBastionSubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    address_prefixes  = ["10.0.8.0/24"]
    network_rules = [
      {
        name                       = "AllowAzureBastionInboundHTTPS"
        priority                   = 102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "*"
        destination_port_range     = "443"
      },
      {
        name                       = "AllowAzureBastionOutboundSSH"
        priority                   = 200
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "VirtualNetwork"
        destination_port_range     = "22"
      },
      {
        name                       = "AllowAzureBastionOutboundRDP"
        priority                   = 201
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "VirtualNetwork"
        destination_port_range     = "3389"
      },
      {
        name                       = "AllowAzureBastionOutboundHTTPS"
        priority                   = 202
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "AzureCloud"
        destination_port_range     = "443"
      },
      {
        name                       = "AllowAzureBastionOutboundInternet"
        priority                   = 203
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "Internet"
        destination_port_range     = "*"
      }
    ]
    routes = [
    ]
  }
  "ClusterSubnet" = {
    name              = "ClusterSubnet"
    service_endpoints = ["Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    address_prefixes  = ["10.0.16.0/20"]
    network_rules = [
    ]
    routes = [
    ]
  }
}
