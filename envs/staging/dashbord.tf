resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "custom-grafana-dashboards"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1" # הלייבל הזה חייב להתאים למה שהגדרנו ב-Helm
    }
  }

  data = {
    "backend_summary_v2.json" = file("${path.module}/dashboards/http_requests.json")
    "pods_health.json"   = file("${path.module}/dashboards/pods_health.json")
    "error_rate_v2.json"    = file("${path.module}/dashboards/error_rate.json")
  }
}