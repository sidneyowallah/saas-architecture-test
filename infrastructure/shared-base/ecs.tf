# This provisions the blank cluster and the IAM Role that gives your Docker containers permission to pull images and write logs to CloudWatch.

resource "aws_ecs_cluster" "shared" {
  name = "saas-backend-cluster" # Looked up by PR scripts
}

# Standard IAM Role for Fargate Execution
resource "aws_iam_role" "ecs_execution" {
  name = "ecsTaskExecutionRole" # Looked up by PR scripts

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}