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

  # הגדרות בסיסיות לניהול הניטור
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false" # מאפשר לפרומתאוס למצוא פודים חדשים אוטומטית
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # הגדרות Grafana
  set {
    name  = "grafana.adminPassword"
    value = "admin" # סיסמה זמנית, נחליף אותה בהמשך
  }

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  depends_on = [module.eks, helm_release.metrics_server]
}