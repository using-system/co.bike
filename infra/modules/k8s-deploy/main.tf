locals {
  default_env_vars = {
    ENVIRONMENT        = var.environment
    DOTNET_ENVIRONMENT = var.environment
    DOTNET_HTTP_PORTS  = var.port
    OTEL_SERVICE_NAME  = var.name
  }

  merged_env_vars = merge(local.default_env_vars, var.env_vars)

  service_account_name = "${var.name}-sa"
}

resource "azuread_application" "this" {
  display_name = "${var.namespace}-${var.name}"
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}


resource "kubernetes_service_account" "this" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace
    annotations = {
      "azure.workload.identity/client-id" = azuread_application.this.client_id
    }
    labels = {
      "azure.workload.identity/use" : "true"
    }
  }
}

resource "azuread_application_federated_identity_credential" "this" {
  application_id = azuread_application.this.id
  display_name   = "${var.namespace}-${var.name}-credential"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject   = "system:serviceaccount:${var.namespace}:${local.service_account_name}"
}

resource "azurerm_role_assignment" "this" {
  count = length(var.role_assignments)

  principal_id         = azuread_service_principal.this.id
  role_definition_name = var.role_assignments[count.index].role_name
  scope                = var.role_assignments[count.index].scope_id
}


resource "kubernetes_deployment" "this" {

  #checkov:skip=CKV_K8S_22  : Use read-only filesystem for containers where possible

  depends_on = [kubernetes_service_account.this]

  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      provisioned_by = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    strategy {
      type = var.strategy

      dynamic "rolling_update" {
        for_each = var.strategy == "RollingUpdate" ? [1] : []
        content {
          max_surge       = "25%"
          max_unavailable = "25%"
        }
      }
    }

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app                           = var.name
          "azure.workload.identity/use" = "true"
          provisioned_by                = "terraform"
        }
      }

      spec {

        node_selector = {
          "kubernetes.azure.com/scalesetpriority" = "spot"
        }

        toleration {
          key      = "kubernetes.azure.com/scalesetpriority"
          operator = "Equal"
          value    = "spot"
          effect   = "NoSchedule"
        }

        service_account_name = local.service_account_name

        security_context {
          run_as_user  = var.run_as_user
          run_as_group = var.run_as_group
        }

        container {
          name  = var.name
          image = var.default_image

          resources {
            limits   = var.resource_limits
            requests = var.resource_requests
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = var.read_only_root_filesystem
            run_as_non_root           = true
          }

          dynamic "env" {
            for_each = local.merged_env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.port
          }

          dynamic "volume_mount" {
            for_each = var.volume_claims
            content {
              mount_path = volume_mount.value.mount_path
              name       = "volume-${volume_mount.value.claim_name}"
              read_only  = volume_mount.value.read_only
            }
          }

          startup_probe {

            dynamic "grpc" {
              for_each = var.health_probe_transport_mode == "grpc" ? [1] : []
              content {
                port = var.port
              }
            }

            dynamic "http_get" {
              for_each = var.health_probe_transport_mode == "http" ? [1] : []
              content {
                path = var.health_probe_path
                port = var.port
              }
            }

            initial_delay_seconds = 15
            period_seconds        = 30
            failure_threshold     = 3
          }

          readiness_probe {

            dynamic "grpc" {
              for_each = var.health_probe_transport_mode == "grpc" ? [1] : []
              content {
                port = var.port
              }
            }

            dynamic "http_get" {
              for_each = var.health_probe_transport_mode == "http" ? [1] : []
              content {
                path = var.health_probe_path
                port = var.port
              }
            }

            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 3
          }

          liveness_probe {

            dynamic "grpc" {
              for_each = var.health_probe_transport_mode == "grpc" ? [1] : []
              content {
                port = var.port
              }
            }

            dynamic "http_get" {
              for_each = var.health_probe_transport_mode == "http" ? [1] : []
              content {
                path = var.health_probe_path
                port = var.port
              }
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            failure_threshold     = 3
          }
        }

        dynamic "volume" {
          for_each = var.volume_claims
          content {
            name = "volume-${volume.value.claim_name}"

            persistent_volume_claim {
              claim_name = volume.value.claim_name
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].image
    ]
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.name
    }

    port {
      port        = var.port
      target_port = var.port
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "this" {
  count = var.ingress_host != "" ? 1 : 0
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"                                  = "azure/application-gateway"
      "appgw.ingress.kubernetes.io/backend-path-prefix"              = "/"
      "appgw.ingress.kubernetes.io/health-probe-path"                = var.health_probe_path
      "appgw.ingress.kubernetes.io/health-probe-port"                = var.port
      "appgw.ingress.kubernetes.io/health-probe-interval"            = "10"
      "appgw.ingress.kubernetes.io/health-probe-timeout"             = "5"
      "appgw.ingress.kubernetes.io/health-probe-unhealthy-threshold" = "3"
      "appgw.ingress.kubernetes.io/appgw-ssl-certificate"            = "cobike-cert"
      "appgw.ingress.kubernetes.io/ssl-redirect"                     = "true"
    }
  }

  spec {
    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/*"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.this.metadata[0].name
              port {
                number = var.port
              }
            }
          }
        }
      }
    }
    dynamic "rule" {
      for_each = var.ingress_host == "www.co.bike" ? [1] : []
      content {
        host = "co.bike"
        http {
          path {
            path      = "/*"
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service.this.metadata[0].name
                port {
                  number = var.port
                }
              }
            }
          }
        }
      }
    }
  }

}

resource "time_sleep" "wait_30_seconds" {
  count           = var.ingress_host != "" ? 1 : 0
  depends_on      = [kubernetes_ingress_v1.this]
  create_duration = "30s"
}

data "kubernetes_ingress_v1" "this" {
  count      = var.ingress_host != "" ? 1 : 0
  depends_on = [time_sleep.wait_30_seconds]
  metadata {
    name      = var.name
    namespace = var.namespace
  }
}

resource "azurerm_dns_a_record" "this" {
  count = var.ingress_host != "" ? 1 : 0

  depends_on = [time_sleep.wait_30_seconds]

  name                = replace(var.ingress_host, ".co.bike", "")
  zone_name           = "co.bike"
  resource_group_name = "cob-hub-infra-we-dns"
  ttl                 = 300
  records             = [data.kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].ip]
}

resource "azurerm_dns_a_record" "this_root" {
  count = var.ingress_host == "www.co.bike" ? 1 : 0

  depends_on = [time_sleep.wait_30_seconds]

  name                = "@"
  zone_name           = "co.bike"
  resource_group_name = "cob-hub-infra-we-dns"
  ttl                 = 300
  records             = [data.kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].ip]
}
