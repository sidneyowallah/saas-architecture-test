# This configures Terraform to save your state file securely in S3 and applies global tags so you can track your AWS billing.   

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "my-saas-terraform-state-bucket"
    key     = "shared-infrastructure/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "my-saas"
      Environment = "Shared-Staging"
      ManagedBy   = "Terraform"
    }
  }
}