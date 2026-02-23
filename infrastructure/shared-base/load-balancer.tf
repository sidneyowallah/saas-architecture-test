# This creates the shared router. When someone visits pr-123.app.yourdomain.com, 
# This ALB receives the request and executes the custom rule that the PR Terraform script attached to it.
# (Note: You must manually generate an ACM Certificate in the AWS Console for *.yourdomain.com and pass the ARN to the certificate_arn variable before running this).

resource "aws_lb" "shared" {
  name               = "saas-shared-alb" # Looked up by PR scripts
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

# Automatically redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Main HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.shared.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  # Default action if someone visits a PR URL that has already been destroyed
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 - Preview Environment Not Found or Destroyed"
      status_code  = "404"
    }
  }
}