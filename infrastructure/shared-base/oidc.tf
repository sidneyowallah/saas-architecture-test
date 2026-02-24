# =========================================================================
# OIDC PROVIDER FOR GITHUB ACTIONS
# =========================================================================

# Define the GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]

  # The thumbprint is required by AWS for OIDC providers
  # This is the official GitHub thumbprint: https://github.blog/changelog/2022-01-13-github-actions-update-on-oidc-based-deployments-to-aws/
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

# Grant the Action Runner the power to log into ECR and push Docker Images
resource "aws_iam_role_policy_attachment" "github_actions_ecr_access" {
  role       = aws_iam_role.github_actions_ecr_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Grant the Action Runner the power to trigger ECS Force New Deployments
resource "aws_iam_role_policy" "github_actions_ecs_update" {
  name = "github-actions-ecs-update-policy"
  role = aws_iam_role.github_actions_ecr_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/saas-backend-cluster/fastify-service",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/saas-frontend-cluster/nginx-frontend-service"
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
