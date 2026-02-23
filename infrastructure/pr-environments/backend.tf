# 1. Target Group (Where the ALB sends traffic)
resource "aws_lb_target_group" "backend_tg" {
  name        = "pr-${var.pr_number}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.shared.id
  target_type = "ip" # Required for ECS Fargate

  health_check {
    path                = "/logs"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    # Fastify might return 401 if accessed without a token, which is actually a healthy sign the API is up!
    matcher             = "200,401,403" 
  }
}

# 2. ALB Listener Rule (The Traffic Cop)
resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 10000 + tonumber(var.pr_number) // to guarantee the ALB rule priority never collides with another open PR!

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    host_header {
      values = [var.backend_host]
    }
  }
}

# 3. ECS Task Definition (The Docker Container)
resource "aws_ecs_task_definition" "backend" {
  family                   = "pr-${var.pr_number}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Keep it tiny/cheap for PR testing! (.25 vCPU)
  memory                   = "512" # 0.5 GB RAM
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/saas-backend:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    environment = [
      { name = "DATABASE_URL", value = "postgres://saas_admin:local_password@staging-db-endpoint:5432/saas_core" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/pr-environments"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend-${var.pr_number}"
        "awslogs-create-group"  = "true"
      }
    }
  }])
}

# 4. ECS Service (Runs the Container)
resource "aws_ecs_service" "backend" {
  name            = "pr-${var.pr_number}-backend-svc"
  cluster         = data.aws_ecs_cluster.shared.id
  task_definition = aws_ecs_task_definition.backend.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Only 1 instance needed for QA testing

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend"
    container_port   = 8080
  }
}