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
    key     = "production/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "my-saas"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}

module "saas_core" {
  source = "../modules/saas_core"

  environment             = "production"
  db_instance_class       = "db.r6g.large" # More powerful for production
  aws_region              = var.aws_region
  db_password             = var.db_password
  certificate_arn         = var.certificate_arn
  keycloak_admin_user     = var.keycloak_admin_user
  keycloak_admin_password = var.keycloak_admin_password
  create_oidc_provider    = false
}
