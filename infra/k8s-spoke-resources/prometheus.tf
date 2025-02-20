locals {
  prometheus_server_service = "prometheus-server.${kubernetes_namespace.prometheus.metadata.0.name}.svc.cluster.local"
  thanos_query_service      = "thanos-query.${kubernetes_namespace.prometheus.metadata.0.name}.svc.cluster.local"
  thanos_store_service      = "thanos-storegateway.${kubernetes_namespace.prometheus.metadata.0.name}.svc.cluster.local"
}

resource "azurerm_resource_group" "prometheus" {
  location = var.location
  name     = "${module.convention.resource_name}-prom"

  tags = var.tags
}

resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"

    labels = {
      istio-injection = "enabled"
      provisioned_by  = "terraform"
    }
  }

}

resource "kubernetes_manifest" "prometheus_peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.prometheus.metadata[0].name
    }
    spec = {
      mtls = {
        mode = "STRICT"
      }
    }
  }
}

resource "kubernetes_manifest" "kube_state_metrics_peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "kube-state-metrics-peer-auth"
      namespace = kubernetes_namespace.prometheus.metadata[0].name
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "kube-state-metrics"
        }
      }
      mtls = {
        mode = "PERMISSIVE"
      }
    }
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

resource "kubernetes_secret" "prometheus_thanos_objstore" {

  depends_on = [kubernetes_namespace.prometheus, azurerm_storage_container.prometheus_thanos]

  metadata {
    name      = "thanos-objstore-secret"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }

  data = {
    "objstore.yml" = templatefile("${path.module}/templates/thanos-objstore.tpl", {
      container_name = azurerm_storage_container.prometheus_thanos.name
      account_name   = azurerm_storage_account.prometheus_thanos.name
      account_key    = azurerm_storage_account.prometheus_thanos.primary_access_key
    })
  }
}

resource "azurerm_role_assignment" "prometheus_thanos_objstore" {
  scope                = azurerm_storage_account.prometheus_thanos.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.aks.principal_id
}

resource "helm_release" "prometheus" {

  depends_on = [kubernetes_secret.prometheus_thanos_objstore, azurerm_role_assignment.prometheus_thanos_objstore]

  name       = "prometheus"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  chart      = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = var.prometheus_helmchart_version

  values = [
    <<EOF
server:
  global:
    external_labels:
      cluster: main
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

  extraArgs:
    storage.tsdb.min-block-duration: "2h"
    storage.tsdb.max-block-duration: "2h"
  sidecarContainers:
    thanos-sidecar:
      image: "${var.thanos_sidecar_image}"
      args:
        - "sidecar"
        - "--log.level=info"
        - "--prometheus.url=http://127.0.0.1:9090"
        - "--tsdb.path=/data"
        - "--objstore.config-file=/etc/thanos/objstore.yml"
      ports:
        - name: http-sidecar
          containerPort: 10902
        - name: grpc
          containerPort: 10901
      volumeMounts:
        - name: storage-volume
          mountPath: /data
        - name: thanos-objstore
          mountPath: /etc/thanos

  extraVolumeMounts:
    - name: thanos-objstore
      mountPath: /etc/thanos

  extraVolumes:
    - name: thanos-objstore
      secret:
        secretName: thanos-objstore-secret
        items:
          - key: "objstore.yml"
            path: "objstore.yml"

  service:
    gRPC:
      enabled: true
      servicePort: 10901

alertmanager:
  persistence:
    size: 2Gi
EOF
  ]
}

resource "helm_release" "thanos" {

  depends_on = [helm_release.prometheus]

  name       = "thanos"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  chart      = "thanos"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  version    = var.thanos_helmchart_version

  values = [
    <<EOF
existingObjstoreSecret: "thanos-objstore-secret"

query:
  enabled: true
  replicaCount: 1
  nodeSelector:
    "kubernetes.azure.com/scalesetpriority": "spot"
  tolerations:
    - key: "kubernetes.azure.com/scalesetpriority"
      operator: "Equal"
      value: "spot"
      effect: "NoSchedule"
  dnsDiscovery:
    enabled: false
  stores:
    - "dns+${local.prometheus_server_service}:10901"
    - "dns+${local.thanos_store_service}:10901"

queryFrontend:
  enabled: true
  replicaCount: 1
  nodeSelector:
    "kubernetes.azure.com/scalesetpriority": "spot"
  tolerations:
    - key: "kubernetes.azure.com/scalesetpriority"
      operator: "Equal"
      value: "spot"
      effect: "NoSchedule"

storegateway:
  enabled: true
  replicaCount: 1
  nodeSelector:
    "kubernetes.azure.com/scalesetpriority": "spot"
  tolerations:
    - key: "kubernetes.azure.com/scalesetpriority"
      operator: "Equal"
      value: "spot"
      effect: "NoSchedule"

compactor:
  enabled: true
  replicaCount: 1
  nodeSelector:
    "kubernetes.azure.com/scalesetpriority": "spot"
  tolerations:
    - key: "kubernetes.azure.com/scalesetpriority"
      operator: "Equal"
      value: "spot"
      effect: "NoSchedule"
EOF
  ]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "thanos_hpa" {

  depends_on = [helm_release.thanos]

  for_each = { for comp in [
    { name = "thanos-query", kind = "Deployment" },
    { name = "thanos-storegateway", kind = "StatefulSet" },
    { name = "thanos-query-frontend", kind = "Deployment" }
  ] : comp.name => comp }

  metadata {
    name      = "hpa-${each.value.name}"
    namespace = kubernetes_namespace.prometheus.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = each.value.kind
      name        = each.value.name
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
