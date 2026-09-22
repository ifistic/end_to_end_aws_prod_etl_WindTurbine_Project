# =============================================================================
# database/secret.tf
# Stores the RDS credentials in AWS Secrets Manager so Glue can read them
# at runtime without the password ever appearing in logs or job arguments.
# =============================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  # Name path makes it easy to find in the console under the project prefix.
  name = "${var.project_name}/${var.environment}/db-credentials"

  description = "RDS PostgreSQL credentials for the wind turbine pipeline"

  # recovery_window_in_days = 0 means delete immediately when Terraform destroys
  # this resource. The default is 30 days, which would block re-creating a secret
  # with the same name if you destroy and re-apply within that window.
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  # Link this version to the secret above.
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Store all five connection fields as JSON so aws_entrypoint.py can parse them
  # with a single GetSecretValue call.
  secret_string = jsonencode({
    username = var.db_username                   # postgres master user
    password = random_password.db_password.result # auto-generated password
    host     = aws_db_instance.main.address      # RDS endpoint hostname
    port     = aws_db_instance.main.port         # always 5432 for PostgreSQL
    dbname   = var.db_name                       # wind_turbine_db
  })
}
