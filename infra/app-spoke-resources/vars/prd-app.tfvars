#------------------------------------------------------------------------------
# Global Variables
#------------------------------------------------------------------------------

tags = {
  project       = "m8t"
  env           = "prd-app"
  provisionedby = "terraform"
}

#------------------------------------------------------------------------------
# Deployments Variables
#------------------------------------------------------------------------------

host_prefix                  = ""
ui_webapp_cpu_request        = "100m"
ui_webapp_memory_request     = "128Mi"
ui_landingapp_cpu_request    = "100m"
ui_landingapp_memory_request = "128Mi"
