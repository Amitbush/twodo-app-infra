terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "twodo-app-tfstate-us-east-1-993412842562"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "twodo-app-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "twodo-app"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

# --- הגדרות לחיבור לקלאסטר ה-EKS ---

# נתונים על הקלאסטר (Token) לצורך התחברות
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Provider עבור ניהול אובייקטים של קוברנטיס
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Provider עבור התקנת אפליקציות עם Helm
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}