variable "aws_region" {
  default = "us-east-1"
  type    = string
}

variable "db_password" {
  description = "Master password for the production database"
  type        = string
  sensitive   = true
}

variable "certificate_arn" {
  description = "The ARN of your ACM Certificate"
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
