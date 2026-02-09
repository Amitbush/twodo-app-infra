################################################################################
# 1. VPC Module - הגדרת רשת קשיחה
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "twodo-app-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw              = true
  map_public_ip_on_launch = true

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/twodo-app-eks" = "shared"
  }

  vpc_tags = {
    "kubernetes.io/cluster/twodo-app-eks" = "shared"
  }
}

################################################################################
# 2. EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "twodo-app-eks"
  cluster_version = "1.31"
  
  create_kms_key = false
  cluster_encryption_config = {}

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets
  cluster_endpoint_public_access = true 

  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 1 
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
}

################################################################################
# 3. Load Balancer Controller - Setup
################################################################################

module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "twodo-app_lb_controller_role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# --- 3.1 תיקון הרשאות ACM לגילוי אוטומטי של תעודות ---
resource "aws_iam_role_policy" "lb_controller_acm" {
  name = "allow-acm-discovery"
  role = module.lb_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "kubernetes_service_account" "lb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
    }
  }
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = "twodo-app-eks"
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.lb_controller_sa.metadata[0].name
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "region"
    value = "us-east-1"
  }
}

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
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }
  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "instance"
  }
  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  depends_on = [module.eks, helm_release.lb_controller]
}

################################################################################
# 5. Secrets
################################################################################

resource "kubernetes_secret" "twodo_secrets" {
  metadata {
    name      = "twodo-secrets"
    namespace = "default"
  }

  data = {
    db-url            = "postgresql://${var.db_user}:${var.db_password}@postgres-service:5432/${var.db_name}"
    db-user           = var.db_user
    db-password       = var.db_password
    postgres-password = var.db_password
    api-url           = "/api"
  }
}
################################################################################
# 6. External-DNS - יצירת רשומות DNS באופן אוטומטי מהקלאסטר
################################################################################

module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name                     = "external-dns-role"
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