# =========================================================================
# OIDC PROVIDER FOR GITHUB ACTIONS
# =========================================================================

data "aws_caller_identity" "current" {}

# Define the GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # The thumbprint is required by AWS for OIDC providers
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# =========================================================================
# IAM ROLE FOR DEPLOYMENT FROM GITHUB ACTIONS
# =========================================================================

# Create the IAM Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions_ecr_deploy" {
  name = "saas-github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          "StringEquals" = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          "StringLike" = {
            # Restrict this role to only be assumed by your specific GitHub repository!
            "token.actions.githubusercontent.com:sub" = "repo:sidneyowallah/saas-architecture-test:*"
          }
        }
      }
    ]
  })
}

# Grant the Action Runner powers to log into ECR and push Docker Images
resource "aws_iam_role_policy_attachment" "github_actions_ecr_access" {
  role       = aws_iam_role.github_actions_ecr_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Grant the Action Runner powers to interact with EKS clusters across environments
resource "aws_iam_role_policy" "github_actions_eks_access" {
  name = "github-actions-eks-access-policy"
  role = aws_iam_role.github_actions_ecr_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        # Allowing access to all saas clusters (staging, production, etc.)
        Resource = [
          "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/saas-*-cluster"
        ]
      }
    ]
  })
}

# Grant the Action Runner power to fetch secrets from SSM Parameter Store
resource "aws_iam_role_policy" "github_actions_ssm_access" {
  name = "github-actions-ssm-access-policy"
  role = aws_iam_role.github_actions_ecr_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/saas/*"
        ]
      }
    ]
  })
}

# Output the new Role ARN for the CI/CD Pipeline
output "github_actions_deploy_role_arn" {
  description = "The IAM Role ARN that GitHub Actions must assume via OIDC to deploy."
  value       = aws_iam_role.github_actions_ecr_deploy.arn
}
