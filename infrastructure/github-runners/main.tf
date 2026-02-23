
# This configures your AWS provider and ensures the Terraform state file is safely stored in S3, 
# completely isolated from your shared-base state.

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
    key     = "github-runners/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "my-saas"
      Environment = "CI-CD"
      ManagedBy   = "Terraform"
    }
  }
}