locals {
  grafana_host           = "${var.ingress_prefix}grafana.co.bike"
  grafana_admin_role_id  = "96258afe-9d90-4d61-905d-94c66707c669"
  grafana_editor_role_id = "3a7eea70-7d6c-4bed-8dad-3d6a1ae6c537"
  grafana_viewer_role_id = "32e68c0e-7dbc-4ee1-bac1-016e218ed69c"
}

resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
  }
}

resource "azuread_application" "grafana" {
  display_name = "${var.env}-grafana"

  web {
    redirect_uris = ["https://${local.grafana_host}/login/azuread"]
  }

  app_role {
    id                   = local.grafana_admin_role_id
    allowed_member_types = ["User"]
    description          = "Admin role for Grafana"
    display_name         = "Admin"
    enabled              = true
    value                = "Admin"
  }

  app_role {
    id                   = local.grafana_editor_role_id
    allowed_member_types = ["User"]
    description          = "Editor role for Grafana"
    display_name         = "Editor"
    enabled              = true
    value                = "Editor"
  }

  app_role {
    id                   = local.grafana_viewer_role_id
    allowed_member_types = ["User"]
    description          = "Viewer role for Grafana"
    display_name         = "Viewer"
    enabled              = true
    value                = "Viewer"
  }

}

resource "azuread_service_principal" "grafana" {
  client_id = azuread_application.grafana.client_id
}

resource "azuread_app_role_assignment" "grafana_admins" {

  depends_on          = [azuread_application.grafana, azuread_service_principal.grafana]
  principal_object_id = data.azuread_group.admin_group.object_id
  app_role_id         = local.grafana_admin_role_id
  resource_object_id  = azuread_service_principal.grafana.object_id
}

resource "azuread_service_principal_password" "grafana" {
  service_principal_id = azuread_service_principal.grafana.id
  end_date             = "2099-01-01T00:00:00Z"
}

resource "kubernetes_secret_v1" "grafana" {
  metadata {
    name      = "grafana-secret"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  data = {
    azuread_client_id     = azuread_application.grafana.client_id
    azuread_client_secret = azuread_service_principal_password.grafana.value
    azuread_tenant_id     = data.azurerm_client_config.current.tenant_id
  }
}


resource "helm_release" "grafana" {
  depends_on = [helm_release.prometheus, kubernetes_namespace.grafana, kubernetes_secret_v1.grafana]

  name       = "grafana"
  namespace  = kubernetes_namespace.grafana.metadata[0].name
  chart      = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  version    = "8.8.2"

  values = [
    <<EOF
envValueFrom:
  GRAFANA_AZUREAD_CLIENT_ID:
    secretKeyRef:
      name: grafana-secret
      key: azuread_client_id
  GRAFANA_AZUREAD_CLIENT_SECRET:
    secretKeyRef:
      name: grafana-secret
      key: azuread_client_secret
  GRAFANA_AZUREAD_TENANT_ID:
    secretKeyRef:
      name: grafana-secret
      key: azuread_tenant_id

nodeSelector:
  "kubernetes.azure.com/scalesetpriority": "spot"
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"

persistence:
  enabled: true
  size: 10Gi
  storageClassName: "default"

grafana.ini:
  server:
    root_url: https://${local.grafana_host}
  auth.azuread:
    name: Azure AD
    enabled: true
    allow_sign_up: true
    client_id: "$${GRAFANA_AZUREAD_CLIENT_ID}"
    client_secret: "$${GRAFANA_AZUREAD_CLIENT_SECRET}"
    scopes: "openid email profile"
    auth_url: "https://login.microsoftonline.com/$${GRAFANA_AZUREAD_TENANT_ID}/oauth2/v2.0/authorize"
    token_url: "https://login.microsoftonline.com/$${GRAFANA_AZUREAD_TENANT_ID}/oauth2/v2.0/token"
    allowed_domains: ""
    allowed_groups: ""

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: ${local.prometehus_server_uri}
        isDefault: true
        jsonData:
          httpMethod: GET

service:
  type: ClusterIP
EOF
  ]
}

resource "kubernetes_ingress_v1" "grafana" {
  depends_on = [helm_release.grafana]

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                       = "azure/application-gateway"
      "appgw.ingress.kubernetes.io/backend-path-prefix"   = "/"
      "appgw.ingress.kubernetes.io/appgw-ssl-certificate" = "cobike-cert"
      "appgw.ingress.kubernetes.io/ssl-redirect"          = "true"
    }
  }

  spec {
    rule {
      host = local.grafana_host
      http {
        path {
          path      = "/*"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [kubernetes_ingress_v1.grafana]
  create_duration = "30s"
}

data "kubernetes_ingress_v1" "grafana" {
  depends_on = [time_sleep.wait_30_seconds]
  metadata {
    name      = "grafana"
    namespace = "grafana"
  }
}

resource "azurerm_dns_a_record" "grafana" {

  depends_on = [time_sleep.wait_30_seconds]

  name                = "${var.ingress_prefix}grafana"
  zone_name           = "co.bike"
  resource_group_name = "cob-hub-infra-we-dns"
  ttl                 = 300
  records             = [data.kubernetes_ingress_v1.grafana.status[0].load_balancer[0].ingress[0].ip]
}
