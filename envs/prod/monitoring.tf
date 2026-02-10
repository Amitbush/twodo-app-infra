################################################################################
# Prometheus & Grafana Stack (Kube-Prometheus-Stack)
################################################################################

resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "62.3.1"

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  depends_on = [module.eks, helm_release.metrics_server]
}

# --- Ingress for Grafana ---
resource "kubernetes_ingress_v1" "grafana_ingress" {
  metadata {
    name      = "grafana-ingress"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" : "alb"
      "alb.ingress.kubernetes.io/scheme" : "internet-facing"
      "alb.ingress.kubernetes.io/target-type" : "ip"
      "alb.ingress.kubernetes.io/group.name" : "twodo-app-stack"
      "alb.ingress.kubernetes.io/listen-ports" : jsonencode([{ "HTTP" = 80 }, { "HTTPS" = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect" : "443"
      "alb.ingress.kubernetes.io/certificate-arn" : aws_acm_certificate.cert.arn
      # Corrected Protocol: Grafana service runs on HTTP
      "alb.ingress.kubernetes.io/backend-protocol" : "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-protocol" : "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path" : "/api/health"
      "alb.ingress.kubernetes.io/success-codes" : "200"
    }
  }

  spec {
    rule {
      host = "grafana.twodo-app.org"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-stack-grafana"
              port {
                # The service port for Grafana is 80, not 3000.
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus_stack]
}
