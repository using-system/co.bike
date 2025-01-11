module "ui_landingapp" {

  depends_on = [kubernetes_namespace.cob]

  source = "../modules/k8s-deploy"

  name                              = "landingapp"
  namespace                         = local.k8s_namespace
  workload_identity_oidc_issuer_url = data.azurerm_kubernetes_cluster.cob.oidc_issuer_url
  environment                       = var.env
  replicas                          = 5

  resource_requests = {
    cpu    = var.ui_landingapp_cpu_request
    memory = var.ui_landingapp_memory_request
  }

  ingress_host            = "${var.host_prefix}www.co.bike"
  ingress_tls_secret_name = module.cob_tls_csi.k8s_secret_name
}
