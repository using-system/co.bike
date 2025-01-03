#------------------------------------------------------------------------------
# Create terraform account to keep tfstate
#------------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    resource_group_name  = "cob-hub-we-storage"
    storage_account_name = "cobhubwetfstate"
    container_name       = "tfstates"
    key                  = "*******"
    subscription_id      = "********-****-****-****-************"
  }

  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.14.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "=3.0.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.35.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "=2.5.2"
    }
  }
}

#------------------------------------------------------------------------------
# Configure the Microsoft Azure Providers
#------------------------------------------------------------------------------

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}

#------------------------------------------------------------------------------
# Configure the k8s Providers
#------------------------------------------------------------------------------

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
