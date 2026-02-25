# This configures Terraform to save your state file securely in S3 and applies global tags so you can track your AWS billing.

variable "environment" {
  description = "The deployment environment (e.g. staging, production)"
  type        = string
}

variable "db_instance_class" {
  description = "The RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

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

variable "keycloak_admin_user" {
  description = "Master admin username for Keycloak"
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Master admin password for Keycloak"
  type        = string
  sensitive   = true
}