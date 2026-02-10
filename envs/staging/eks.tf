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
      desired_size = 2
      min_size     = 2
      max_size     = 3 
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
}