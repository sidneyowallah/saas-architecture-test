# These are the credentials you will generate from your GitHub App. Because they are marked sensitive = true, 
# Terraform will never print them in the terminal logs.

variable "aws_region" {
  default = "us-east-1"
  type    = string
}

variable "github_app_id" {
  description = "The App ID from your GitHub App configuration"
  type        = string
}

variable "github_webhook_secret" {
  description = "The random webhook secret you created in GitHub"
  type        = string
  sensitive   = true
}

variable "github_app_key_base64" {
  description = "The Base64 encoded PEM file downloaded from GitHub"
  type        = string
  sensitive   = true
}