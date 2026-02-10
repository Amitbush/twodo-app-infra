################################################################################
# 1. VPC Module - הגדרת רשת קשיחה
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "twodo-prod-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  create_igw              = true
  map_public_ip_on_launch = true

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/twodo-prod-eks" = "shared"
  }

  vpc_tags = {
    "kubernetes.io/cluster/twodo-prod-eks" = "shared"
  }
}