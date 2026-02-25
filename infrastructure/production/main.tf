terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
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

provider "kubernetes" {
  host                   = module.saas_core.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.saas_core.eks_cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.saas_core.eks_cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.saas_core.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.saas_core.eks_cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.saas_core.eks_cluster_name]
      command     = "aws"
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
