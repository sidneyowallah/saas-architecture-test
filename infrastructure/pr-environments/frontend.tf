resource "aws_lb_target_group" "frontend_tg" {
  name        = "pr-${var.pr_number}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.shared.id
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 20000 + tonumber(var.pr_number) # Offset by 20000 to avoid backend collisions

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }

  condition {
    host_header {
      values = [var.frontend_host]
    }
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "pr-${var.pr_number}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/saas-frontend:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/pr-environments"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend-${var.pr_number}"
        "awslogs-create-group"  = "true"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "pr-${var.pr_number}-frontend-svc"
  cluster         = data.aws_ecs_cluster.shared.id
  task_definition = aws_ecs_task_definition.frontend.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 80
  }
}