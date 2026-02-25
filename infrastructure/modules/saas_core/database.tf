# This provisions a standard, cloud-agnostic PostgreSQL RDS instance
# avoiding proprietary Aurora extensions to ensure easy migration to other cloud providers later.

resource "aws_db_subnet_group" "postgres" {
  name       = "saas-${var.environment}-postgres-subnets"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_db_instance" "shared_postgres" {
  identifier           = "saas-${var.environment}-db"
  engine               = "postgres"
  engine_version       = "15.10"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  
  db_name              = "saas_core"
  username             = "saas_admin"
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  # For a staging DB, skip the final snapshot on destroy
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# Output the database URL so it can be injected into the Kubernetes External Secrets or CI/CD
output "database_endpoint" {
  value = aws_db_instance.shared_postgres.endpoint
}