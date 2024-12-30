#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------

tags = {
  project       = "cob"
  env           = "stg-infra"
  provisionedby = "terraform"
}

#------------------------------------------------------------------------------
# NETWORKING
#------------------------------------------------------------------------------

vnet_address_space = "192.168.0.0/16"
vnet_subnets = {
  "ClusterSubnet" = {
    name              = "ClusterSubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    address_prefixes  = ["192.168.0.0/20"]
    network_rules = [
    ]
    routes = [
    ]
  },
  "AppGtwSubnet" = {
    name              = "AppGtwSubnet"
    service_endpoints = ["Microsoft.KeyVault"]
    address_prefixes  = ["192.168.16.0/24"]
    network_rules = [
      {
        name                       = "Allow-Ephemeral-Ports-Inbound"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "*"
        destination_port_range     = "65200-65535"
      },
      {
        name                       = "Allow-Ephemeral-Ports-Outbound"
        priority                   = 1002
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "*"
        destination_port_range     = "65200-65535"
      },
      {
        name                       = "AllowAnyHTTPSInbound"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "*"
        destination_port_range     = "443"
      },
      {
        name                       = "AllowAnyHTTPInbound"
        priority                   = 1004
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_address_prefix = "*"
        destination_port_range     = "80"
      },
    ]
    routes = [
    ]
  },
  "ResourcesSubnet" = {
    name              = "ResourcesSubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    address_prefixes  = ["192.168.17.0/24"]
    network_rules = [
    ]
    routes = [
    ]
  },
  "AcaSubnet" = {
    name              = "AcaSubnet"
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
    address_prefixes  = ["192.168.18.0/23"]
    network_rules = [
    ]
    routes = [
    ]
  }
}

#------------------------------------------------------------------------------
# GITHUB RUNNER Variables
#------------------------------------------------------------------------------

gh_runner_labels = "cob,stg-infra,dev-app,prd-app"
