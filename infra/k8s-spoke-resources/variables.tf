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

variable "tags" {
  description = "The default tags to associate with resources."
  type        = map(string)
}

#------------------------------------------------------------------------------
# Kubernetes Variables
#------------------------------------------------------------------------------

variable "ingress_prefix" {
  description = "Ingress prefix"
}
