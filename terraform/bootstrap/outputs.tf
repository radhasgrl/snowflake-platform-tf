output "state_bucket_name" {
  description = "S3 bucket name — use this in your foundation backend config"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table name — use this in your foundation backend config"
  value       = aws_dynamodb_table.tf_lock.name
}

output "aws_region" {
  value = var.aws_region
}
