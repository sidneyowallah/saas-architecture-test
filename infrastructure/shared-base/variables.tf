# This configures Terraform to save your state file securely in S3 and applies global tags so you can track your AWS billing.

variable "aws_region" {
  default = "us-east-1"
  type    = string
}

variable "db_password" {
  description = "Master password for the shared Aurora Postgres database"
  type        = string
  sensitive   = true # Hides the password from console logs!
}

variable "certificate_arn" {
  description = "The ARN of your ACM Certificate for *.yourdomain.com"
  type        = string
}