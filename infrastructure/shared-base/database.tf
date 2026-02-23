# This provisions your shared Staging database. Because it is Serverless v2, it scales down to 0.5 ACUs 
# (saving you massive amounts of money at night when developers are asleep), but scales up instantly when CI runs tests

resource "aws_db_subnet_group" "aurora" {
  name       = "saas-aurora-subnets"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_rds_cluster" "shared_aurora" {
  cluster_identifier      = "saas-staging-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.8" # Highly stable PG version for Drizzle ORM
  database_name           = "saas_core"
  master_username         = "saas_admin"
  master_password         = var.db_password
  
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  
  # For a staging DB, you typically skip the final snapshot on destroy
  skip_final_snapshot     = true 

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }
}

resource "aws_rds_cluster_instance" "shared_aurora_instance" {
  cluster_identifier = aws_rds_cluster.shared_aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.shared_aurora.engine
  engine_version     = aws_rds_cluster.shared_aurora.engine_version
}

# Output the database URL so you can inject it into GitHub Secrets later
output "database_endpoint" {
  value = aws_rds_cluster.shared_aurora.endpoint
}