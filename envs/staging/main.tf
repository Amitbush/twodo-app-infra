################################################################################
# 1. VPC Module - הרשת
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw              = true  # יוצר Internet Gateway
  map_public_ip_on_launch = true  # מאפשר כתובות IP ציבוריות

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # התיקון: וידוא טאגים מדויקים עבור ה-ALB Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

################################################################################
# 2. EKS Module - הקלאסטר
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "${var.project_name}-eks"
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
      max_size     = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      associate_public_ip_address = true
    }
  }

  tags = {
    Environment = "staging"
    Terraform   = "true"
    Project     = var.project_name
  }
}

################################################################################
# 3. IAM Role עבור ה-Load Balancer Controller
################################################################################

module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "${var.project_name}_lb_controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

################################################################################
# 3.1 תיקון הרשאות (מעודכן עם הרשאות גילוי סאבנטים)
################################################################################

resource "aws_iam_role_policy" "lb_controller_fix" {
  name = "ALBControllerAdditionalPerms"
  role = module.lb_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListenerAttributes",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# 4. התקנת AWS Load Balancer Controller
################################################################################

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role.iam_role_arn
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "region"
    value = var.region
  }

  depends_on = [module.eks, aws_iam_role_policy.lb_controller_fix]
}

################################################################################
# 5. Security Group ייעודי ל-ALB
################################################################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-public-sg"
  description = "Shared Security Group for Twodo App ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                     = "${var.project_name}-alb-public-sg"
    "elbv2.k8s.aws/resource" = "shared"
  }
}

################################################################################
# 5.1 תיקון ה-Health Check
################################################################################

resource "aws_security_group_rule" "allow_alb_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow all traffic from ALB SG to EKS nodes"
}

################################################################################
# 6. אוטומציה של ה-Secrets (מנוקה מסיסמאות חשופות)
################################################################################

resource "kubernetes_secret" "twodo_secrets" {
  metadata {
    name      = "twodo-secrets"
    namespace = "default"
  }

  data = {
    # הנתונים נמשכים כעת ממשתנים בקובץ variables.tf או terraform.tfvars
    db-url            = "postgresql://${var.db_user}:${var.db_password}@postgres-service:5432/${var.db_name}"
    db-user           = var.db_user
    db-password       = var.db_password
    postgres-password = var.db_password
    api-url           = "/api"
  }

  depends_on = [module.eks]
}

################################################################################
# 7. התקנת ArgoCD
################################################################################

resource "helm_release" "argocd" {
  name               = "argocd"
  repository         = "https://argoproj.github.io/argo-helm"
  chart              = "argo-cd"
  namespace          = "argocd"
  create_namespace   = true
  wait               = false

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}