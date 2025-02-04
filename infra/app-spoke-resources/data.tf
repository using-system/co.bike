data "azurerm_client_config" "current" {

}

data "azurerm_key_vault" "hub" {
  name                = "cob-hub-infra-we"
  resource_group_name = "cob-hub-infra-we-vault"
}
data "azurerm_kubernetes_cluster" "cob" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}
