# This is how the runners know where to live. 
# It looks up the VPC and Private Subnets you already provisioned in the shared-base

# 1. Look up the Shared VPC
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["saas-vpc"]
  }
}

# 2. Look up the Private Subnets inside that VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  tags = {
    Tier = "Private"
  }
}