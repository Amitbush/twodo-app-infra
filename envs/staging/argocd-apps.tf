################################################################################
# ArgoCD Root Application (App-of-Apps)
################################################################################

resource "kubernetes_manifest" "root_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root-apps"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/Amitbush/twodo-app-gitops.git"
        targetRevision = "main"
        path           = "apps"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  # אנחנו עדיין צריכים את ה-depends_on כדי לוודא שארגו קיים
  depends_on = [helm_release.argocd]
}