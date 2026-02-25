# =========================================================================
# SECRETS MANAGEMENT
# These secrets are stored in AWS Systems Manager Parameter Store.
# In the new Cloud-Agnostic architecture, the Kubernetes External Secrets
# Operator will securely sync these values into native Kubernetes Secrets
# so the application pods can consume them without AWS-specific SDKs.
# =========================================================================

resource "aws_ssm_parameter" "keycloak_admin_password" {
  name        = "/saas/${var.environment}/keycloak/admin-password"
  description = "Keycloak Master Admin Password"
  type        = "SecureString"
  value       = var.keycloak_admin_password
  overwrite   = true
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/saas/${var.environment}/database/password"
  description = "Shared PostgreSQL Database Master Password"
  type        = "SecureString"
  value       = var.db_password
  overwrite   = true
}

resource "aws_ssm_parameter" "keycloak_admin_user" {
  name        = "/saas/${var.environment}/keycloak/admin-user"
  description = "Keycloak Master Admin Username"
  type        = "String"
  value       = var.keycloak_admin_user
  overwrite   = true
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/saas/${var.environment}/database/url"
  description = "PostgreSQL Database URL"
  type        = "SecureString"
  # Constructing the connection string with the correct username 'saas_admin'
  value       = "postgres://saas_admin:${var.db_password}@${aws_db_instance.shared_postgres.endpoint}/saas_core"
  overwrite   = true
}
