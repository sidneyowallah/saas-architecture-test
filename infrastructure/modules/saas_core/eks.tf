# This provisions the EKS cluster to replace the previous ECS Fargate setup.
# Uses the official terraform-aws-modules/eks/aws module.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "saas-${var.environment}-cluster"
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Enable OIDC provider so we can use IRSA (IAM Roles for Service Accounts)
  # This is how pods will securely access AWS resources (like parameter store or S3)
  enable_irsa = true

  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  # Allow the current caller (the GitHub Action runner or local dev) to manage the cluster
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    sowallah = {
      principal_arn     = "arn:aws:iam::569758639273:user/sowallah"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_actions = {
      principal_arn     = aws_iam_role.github_actions_ecr_deploy.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Environment = "saas-${var.environment}"
  }
}

# The IAM role for External Secrets or other pods to read SSM Parameter Store securely
module "iam_role_for_service_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "saas-${var.environment}-eks-ssm-secrets-reader"

  role_policy_arns = {
    policy = aws_iam_policy.eks_ssm_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_policy" "eks_ssm_secrets" {
  name        = "saas-${var.environment}-eks-ssm-secrets-policy"
  description = "Allows EKS pods to read secrets from SSM securely"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/saas/${var.environment}/*"
      }
    ]
  })
}

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "aws-lb-controller-${var.environment}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}
