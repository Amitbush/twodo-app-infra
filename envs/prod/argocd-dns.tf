################################################################################
# 4. ArgoCD
################################################################################

resource "helm_release" "argocd" {
  name               = "argocd"
  repository         = "https://argoproj.github.io/argo-helm"
  chart              = "argo-cd"
  namespace          = "argocd"
  create_namespace   = true

  # The chart defaults to ClusterIP, which is correct for Ingress.
  # No overrides are needed here anymore.

  depends_on = [module.eks, helm_release.lb_controller]
}

# --- Ingress for ArgoCD ---
resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class" : "alb"
      "alb.ingress.kubernetes.io/scheme" : "internet-facing"
      "alb.ingress.kubernetes.io/target-type" : "ip"
      "alb.ingress.kubernetes.io/group.name" : "twodo-app-stack"
      "alb.ingress.kubernetes.io/listen-ports" : jsonencode([{ "HTTP" = 80 }, { "HTTPS" = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect" : "443"
      "alb.ingress.kubernetes.io/certificate-arn" : aws_acm_certificate.cert.arn
      # Corrected Protocol: ArgoCD service runs on HTTP
      "alb.ingress.kubernetes.io/backend-protocol" : "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-protocol" : "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path" : "/healthz"
      "alb.ingress.kubernetes.io/success-codes" : "200"
    }
  }

  spec {
    rule {
      host = "argocd.twodo-app.org"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}


################################################################################
# 6. External-DNS - Creates DNS records automatically from the cluster
################################################################################

module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name                     = "external-dns-prod-role"
  attach_external_dns_policy    = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "kubernetes_service_account" "external_dns_sa" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns_role.iam_role_arn
    }
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.13.0"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.external_dns_sa.metadata[0].name
  }
  set {
    name  = "source"
    value = "ingress"
  }
  set {
    name  = "domainFilters[0]"
    value = "twodo-app.org"
  }
  set {
    name  = "provider"
    value = "aws"
  }
  
  depends_on = [module.eks]
}
