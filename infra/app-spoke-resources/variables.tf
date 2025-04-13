
#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
}

variable "location" {
  description = "Azure Location name"
  default     = "westeurope"
}

variable "location_short_name" {
  description = "Azure Location short name"
  default     = "we"
}

variable "env" {
  description = "Environment name"
}

variable "project_name" {
  description = "Project name"
  default     = "m8t"
}

variable "dns_zone_name" {
  description = "The DNS zone name"
  default     = "m8te.ai"

}

variable "tags" {
  description = "The default tags to associate with resources."
  type        = map(string)
}


#------------------------------------------------------------------------------
# AKS Variables
#------------------------------------------------------------------------------

variable "aks_cluster_name" {
  description = "The name of the AKS cluster"
}

variable "aks_resource_group_name" {
  description = "The name of the resource group containing the AKS cluster"
}

#------------------------------------------------------------------------------
# Deployments Variables
#------------------------------------------------------------------------------

variable "host_prefix" {
  description = "The prefix for the hostnames"
}

variable "ui_webapp_cpu_request" {
  description = "The CPU request for the UI webapp"
}

variable "ui_webapp_memory_request" {
  description = "The memory request for the UI webapp"
}

variable "ui_landingapp_cpu_request" {
  description = "The CPU request for the UI landingapp"
}

variable "ui_landingapp_memory_request" {
  description = "The memory request for the UI landingapp"
}
