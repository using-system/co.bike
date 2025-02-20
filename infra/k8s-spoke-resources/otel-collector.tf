resource "kubernetes_namespace" "otel_collector" {
  metadata {
    name = "otel-collector"

    labels = {
      istio-injection = "enabled"
      provisioned_by  = "terraform"
    }
  }
}

resource "kubernetes_manifest" "otel_collector_peer_authentication" {
  manifest = {
    apiVersion = "security.istio.io/v1beta1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.otel_collector.metadata[0].name
    }
    spec = {
      mtls = {
        mode = "STRICT"
      }
    }
  }
}

resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = kubernetes_namespace.otel_collector.metadata[0].name
  create_namespace = false
  version          = var.otel_collector_helmchart_version

  values = [
    <<-EOF
    nodeSelector:
      "kubernetes.azure.com/scalesetpriority": "spot"
    tolerations:
      - key: "kubernetes.azure.com/scalesetpriority"
        operator: "Equal"
        value: "spot"
        effect: "NoSchedule"
    image:
      repository: otel/opentelemetry-collector-contrib
    mode: deployment
    config:
      processors:
        batch: {}
      exporters:
        prometheusremotewrite:
          endpoint: "http://${local.thanos_store_service}:10901/api/v1/receive"
      service:
        pipelines:
          metrics:
            receivers: [otlp]
            processors: [batch]
            exporters: [debug, prometheusremotewrite]
    EOF
  ]
}
