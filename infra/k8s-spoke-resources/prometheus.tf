locals {
  prometehus_server_uri = "http://prometheus-server.${kubernetes_namespace.prometheus.metadata.0.name}.svc.cluster.local:80"
}

resource "azurerm_resource_group" "prometheus" {
  location = var.location
  name     = "${module.convention.resource_name}-prom"

  tags = var.tags
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "azurerm_user_assigned_identity" "prometheus" {
  location            = var.location
  name                = "prometheus-identity"
  resource_group_name = azurerm_resource_group.prometheus.name

  tags = var.tags
}

resource "azurerm_storage_account" "prometheus_thanos" {

  #checkov:skip=CKV_AZURE_244  : Avoid the use of local users for Azure Storage unless necessary  
  #checkov:skip=CKV_AZURE_33   : Ensure Storage logging is enabled for Queue service for read, write and delete requests
  #checkov:skip=CKV2_AZURE_33  : Ensure storage account is configured with private endpoint         
  #checkov:skip=CKV2_AZURE_41  : Ensure storage account is configured with SAS expiration policy
  #checkov:skip=CKV2_AZURE_40  : Ensure storage account is not configured with Shared Key authorization      
  #checkov:skip=CKV2_AZURE_1   : Ensure storage for critical data are encrypted with Customer Managed Key

  depends_on = [azurerm_resource_group.prometheus]

  name                     = "${module.convention.resource_name_without_delimiter}thanos"
  resource_group_name      = azurerm_resource_group.prometheus.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.prometheus.id]
  }

  tags = var.tags
}


resource "azurerm_private_endpoint" "prometheus_thanos" {
  name                = "promthanospep"
  location            = var.location
  resource_group_name = azurerm_resource_group.prometheus.name

  subnet_id = data.azurerm_subnet.resources.id

  private_dns_zone_group {
    name                 = "promthanospep-dzg"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }


  private_service_connection {
    name                           = "promthanospep-cnx"
    private_connection_resource_id = azurerm_storage_account.prometheus_thanos.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = var.tags
}

resource "time_sleep" "wait_30_seconds_after_thanos_pep" {
  depends_on      = [azurerm_private_endpoint.prometheus_thanos]
  create_duration = "30s"
}

resource "azurerm_storage_container" "prometheus_thanos" {

  #checkov:skip=CKV2_AZURE_21 : Ensure Storage logging is enabled for Blob service for read requests

  depends_on            = [time_sleep.wait_30_seconds_after_thanos_pep]
  name                  = "thanos"
  storage_account_id    = azurerm_storage_account.prometheus_thanos.id
  container_access_type = "private"
}


resource "helm_release" "prometheus" {

  depends_on = [kubernetes_namespace.prometheus]

  name       = "prometheus"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "26.0.1"

  values = [
    <<EOF
server:
  nodeSelector:
    "kubernetes.azure.com/scalesetpriority": "spot"
  tolerations:
    - key: "kubernetes.azure.com/scalesetpriority"
      operator: "Equal"
      value: "spot"
      effect: "NoSchedule"
  persistentVolume:
    enabled: true
    size: 30Gi
    storageClass: "managed-premium"

alertmanager:
  persistence:
    size: 2Gi
EOF
  ]
}


/*
resource "kubernetes_horizontal_pod_autoscaler_v2" "prometheus" {

  depends_on = [helm_release.prometheus]

  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = "prometheus-server"
      api_version = "apps/v1"
    }

    min_replicas = 3
    max_replicas = 8

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}
*/
