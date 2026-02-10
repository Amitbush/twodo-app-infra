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
    key            = "prod/terraform.tfstate"
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
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

# --- הגדרות לחיבור לקלאסטר ה-EKS ---
# הזרקת Token דינמי בכל הרצה כדי למנוע שגיאות Unreachable

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # חשוב: אנחנו משתמשים בשם הקלאסטר המפורש כדי למנוע טעויות בזמן ה-Bootstrap
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "twodo-prod-eks", "--region", "us-east-1"]
    }
  }
}