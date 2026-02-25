# We use the official, industry-standard AWS VPC module. 
#Notice the private_subnet_tags block—this exact tag (Tier = "Private") is what the PR scripts use to dynamically find where to deploy the containers.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "saas-${var.environment}-vpc" # Looked up by PR scripts
  cidr = "10.0.0.0/16"

  azs              = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Keeps costs down for staging environments
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Crucial: Allows the PR environments to lookup subnets automatically
  # Also required for EKS internal load balancers
  private_subnet_tags = {
    Tier = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}