################################################################################
# VPC Outputs
################################################################################
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

################################################################################
# EKS Outputs
################################################################################
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

################################################################################
# RDS Outputs (תיקון מדויק לפי הקוד שלך)
################################################################################
# שים לב: כאן השתמשת ב-resource ולא ב-module, לכן התיקון הוא ל-aws_db_instance
output "rds_hostname" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "The database port"
  value       = aws_db_instance.postgres.port
}

output "rds_endpoint" {
  description = "The connection endpoint"
  value       = aws_db_instance.postgres.endpoint
}