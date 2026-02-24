# =========================================================================
# 1. APPLICATION LOAD BALANCER TARGET GROUPS
# =========================================================================

# Backend Target Group (Fastify runs on port 8080)
resource "aws_lb_target_group" "backend_tg" {
  name        = "saas-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Frontend Target Group (Nginx runs on port 80)
resource "aws_lb_target_group" "frontend_tg" {
  name        = "saas-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# =========================================================================
# 2. ALB LISTENER RULES
# =========================================================================

# Rule 1: Route api.* to the Backend
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    host_header {
      values = ["api.*"]
    }
  }
}

# Rule 2: Route everything else (e.g. root domain) to the Frontend
resource "aws_lb_listener_rule" "frontend_routing" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# =========================================================================
# 3. CLOUDWATCH LOG GROUPS
# =========================================================================

resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/ecs/saas-backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "frontend_logs" {
  name              = "/ecs/saas-frontend"
  retention_in_days = 14
}

# =========================================================================
# 4. ECS TASK DEFINITIONS
# =========================================================================

data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "backend_task" {
  family                   = "saas-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "saas-backend"
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/saas-backend:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "DATABASE_URL"
        value = "postgresql://saas_admin:${var.db_password}@${aws_rds_cluster.shared_aurora.endpoint}:5432/saas_core?sslmode=require"
      },
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "KEYCLOAK_URL"
        value = "https://${aws_lb.shared.dns_name}/auth"
      },
      {
        name  = "NODE_TLS_REJECT_UNAUTHORIZED"
        value = "0"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "saas-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "saas-frontend"
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/saas-frontend:latest"
    essential = true

    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

# =========================================================================
# 5. ECS SERVICES
# =========================================================================

resource "aws_ecs_service" "backend_service" {
  name            = "fastify-service" # This perfectly matches your ci-cd.yml target!
  cluster         = aws_ecs_cluster.shared.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "saas-backend"
    container_port   = 8080
  }

  # Allow the CI/CD pipeline to safely update the task definition outside of Terraform
  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_cluster" "frontend_cluster" {
  name = "saas-frontend-cluster" # This perfectly matches your ci-cd.yml target!
}

resource "aws_ecs_service" "frontend_service" {
  name            = "nginx-frontend-service" # This perfectly matches your ci-cd.yml target!
  cluster         = aws_ecs_cluster.frontend_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "saas-frontend"
    container_port   = 80
  }

  # Allow the CI/CD pipeline to safely update the task definition outside of Terraform
  lifecycle {
    ignore_changes = [task_definition]
  }
}
