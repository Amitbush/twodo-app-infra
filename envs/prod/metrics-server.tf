################################################################################
# Metrics Server - מאפשר לקוברנטיס למדוד ניצול משאבים (CPU/RAM)
################################################################################

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1" # גרסה יציבה

  # הגדרות נחוצות לעבודה חלקה ב-EKS
  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }

  # מבטיח שההתקנה תתבצע רק אחרי שהקלאסטר וה-Nodes מוכנים
  depends_on = [module.eks]
}