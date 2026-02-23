variable "pr_number" {
  description = "The Pull Request Number (used for naming and unique ALB rule priorities)"
  type        = string
}

variable "image_tag" {
  description = "The Docker image tag (e.g., pr-123)"
  type        = string
}

variable "frontend_host" {
  description = "The URL for the frontend (e.g., pr-123.app.yourdomain.com)"
  type        = string
}

variable "backend_host" {
  description = "The URL for the backend API (e.g., pr-123.api.yourdomain.com)"
  type        = string
}

variable "aws_region" {
  default = "us-east-1"
  type    = string
}