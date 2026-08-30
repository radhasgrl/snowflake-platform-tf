variable "aws_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  default     = "snowflake-platform-tf-state-525218385225"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "snowflake-platform-tf-lock"
}
