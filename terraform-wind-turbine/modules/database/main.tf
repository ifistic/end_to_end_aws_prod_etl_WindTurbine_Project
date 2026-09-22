# =============================================================================
# database/main.tf
# Creates the RDS PostgreSQL instance that the pipeline writes results into.
# Also creates the DB subnet group that tells RDS which subnets it can use.
# =============================================================================

# DB subnet group: RDS requires at least two subnets in different AZs.
# We pass in the two private subnets from the network module.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids # two private subnets in different AZs
  tags       = var.tags
}

# random_password generates a secure 24-character password automatically.
# special = false avoids characters like @, /, + that break connection strings.
# The result is stored in Secrets Manager (see secret.tf) so Glue can read it.
resource "random_password" "db_password" {
  length  = 24  # long enough to be secure
  special = false # no special chars that break connection strings
}

# The RDS PostgreSQL instance.
resource "aws_db_instance" "main" {
  # identifier: the name shown in the AWS console and used in the endpoint URL.
  identifier = "${var.project_name}-${var.environment}"

  # Engine settings.
  engine         = "postgres"       # PostgreSQL engine
  engine_version = var.engine_version # pin the version (default 18.1)

  # Instance size and storage.
  instance_class    = var.db_instance_class       # e.g. db.t4g.micro
  allocated_storage = var.db_allocated_storage_gb # in GB
  storage_type      = "gp3"                       # gp3 is cheaper than gp2
  storage_encrypted = true                        # encrypt at rest, no extra cost

  # Database credentials.
  db_name  = var.db_name                          # the database to create inside Postgres
  username = var.db_username                      # the master username
  password = random_password.db_password.result   # the auto-generated password

  # Networking: put RDS in the private subnets, behind the pipeline security group.
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false # never expose RDS to the internet

  # Backups: keep 7 days of automated backups.
  backup_retention_period = 7

  # skip_final_snapshot = true: when Terraform destroys this instance, do NOT
  # take a final snapshot first. This lets `terraform destroy` complete cleanly
  # without leaving orphaned snapshots in your AWS account.
  skip_final_snapshot = true

  # deletion_protection = false: allow Terraform to delete this instance.
  # Set to true in production to prevent accidental deletion.
  deletion_protection = false

  tags = var.tags
}
