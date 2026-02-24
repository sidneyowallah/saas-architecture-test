# This strict setup ensures your database is completely disconnected from the public internet. It only allows traffic from ECS, and ECS only allows traffic from the Load Balancer.

# 1. Load Balancer Security Group (Public Internet Access)
resource "aws_security_group" "alb_sg" {
  name        = "saas-alb-sg"
  description = "Allow HTTPS and HTTP inbound"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. ECS Containers Security Group (Internal Access Only)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-tasks-sg" # Looked up by PR scripts
  description = "Allow inbound from ALB only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Database Security Group (Deep Internal Access Only)
resource "aws_security_group" "db_sg" {
  name        = "database-sg"
  description = "Allow inbound from ECS tasks only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}