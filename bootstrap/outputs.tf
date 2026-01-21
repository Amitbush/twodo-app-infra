output "tfstate_bucket_name" {
  value       = aws_s3_bucket.tfstate.id
  description = "Copy this to your envs/staging/providers.tf"
}

output "tflock_table_name" {
  value       = aws_dynamodb_table.tflock.name
  description = "Copy this to your envs/staging/providers.tf"
}