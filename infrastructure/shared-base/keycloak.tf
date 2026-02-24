# =========================================================================
# 1. KEYCLOAK TARGET GROUP & LOAD BALANCER
# =========================================================================

resource "aws_lb_target_group" "keycloak_tg" {
  name        = "saas-keycloak-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    # Keycloak 24 health endpoint (updated for context path)
    path                = "/auth/health/ready"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Route /auth/* to Keycloak
resource "aws_lb_listener_rule" "keycloak_routing" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak_tg.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*"]
    }
  }
}

# =========================================================================
# 2. KEYCLOAK CLOUDWATCH LOGS
# =========================================================================

resource "aws_cloudwatch_log_group" "keycloak_logs" {
  name              = "/ecs/saas-keycloak"
  retention_in_days = 14
}

# =========================================================================
# 3. KEYCLOAK ECS TASK DEFINITION
# =========================================================================

resource "aws_ecs_task_definition" "keycloak_task" {
  family                   = "saas-keycloak-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512 # Keycloak is Java-based and requires more CPU/Memory than Node
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "saas-keycloak"
    image     = "quay.io/keycloak/keycloak:24.0.0"
    essential = true

    # Run in dev mode to skip build steps, but configure the Edge proxy for ALB
    command = ["start-dev"]

    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "KEYCLOAK_ADMIN"
        value = var.keycloak_admin_user
      },
      {
        name  = "KEYCLOAK_ADMIN_PASSWORD"
        value = var.keycloak_admin_password
      },
      {
        name  = "KC_DB"
        value = "postgres"
      },
      {
        name  = "KC_DB_URL"
        value = "jdbc:postgresql://${aws_rds_cluster.shared_aurora.endpoint}:5432/saas_core?ssl=true&sslmode=require"
      },
      {
        name  = "KC_DB_USERNAME"
        value = "saas_admin"
      },
      {
        name  = "KC_DB_PASSWORD"
        value = var.db_password
      },
      {
        name  = "KC_PROXY_HEADERS"
        value = "xforwarded"
      },
      {
        # Workaround for dev mode behind ALB (disables strict hostname checks)
        name  = "KC_HOSTNAME_STRICT"
        value = "false"
      },
      {
        name  = "KC_HTTP_ENABLED"
        value = "true"
      },
      {
        name  = "KC_HTTP_RELATIVE_PATH"
        value = "/auth"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.keycloak_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "keycloak"
      }
    }
  }])
}

# =========================================================================
# 4. KEYCLOAK ECS SERVICE
# =========================================================================

resource "aws_ecs_service" "keycloak_service" {
  name            = "saas-keycloak-service"
  cluster         = aws_ecs_cluster.shared.id
  task_definition = aws_ecs_task_definition.keycloak_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak_tg.arn
    container_name   = "saas-keycloak"
    container_port   = 8080
  }
}
