################################################################################
# 4. ArgoCD
################################################################################

resource "helm_release" "argocd" {
  name               = "argocd"
  repository         = "https://argoproj.github.io/argo-helm"
  chart              = "argo-cd"
  namespace          = "argocd"
  create_namespace   = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [module.eks, helm_release.lb_controller]
  timeout = 600
}

################################################################################
# 6. External-DNS - יצירת רשומות DNS באופן אוטומטי מהקלאסטר
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