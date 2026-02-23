terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # When using Terraform Workspaces, Terraform automatically appends 
  # `env:/pr-123/` to this S3 key, keeping every PR state perfectly isolated!
  backend "s3" {
    bucket         = "my-saas-terraform-state-bucket"
    key            = "pr-environments/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  # Automatically tag every resource created by this script with the PR number
  # so you can easily track costs in the AWS Billing Dashboard
  default_tags {
    tags = {
      Environment = "PR-${var.pr_number}"
      ManagedBy   = "Terraform-Ephemeral"
    }
  }
}

# =========================================================
# DATA SOURCES (Look up existing shared infrastructure)
# =========================================================

data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["saas-vpc"] # The name of the VPC created in your main infrastructure
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  # Assumes you tagged your private subnets with Tier = Private
  tags = {
    Tier = "Private"
  }
}

data "aws_ecs_cluster" "shared" {
  cluster_name = "saas-backend-cluster"
}

data "aws_lb" "shared" {
  name = "saas-shared-alb"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

data "aws_iam_role" "ecs_execution" {
  name = "ecsTaskExecutionRole"
}

data "aws_security_group" "ecs_sg" {
  name = "ecs-tasks-sg"
}