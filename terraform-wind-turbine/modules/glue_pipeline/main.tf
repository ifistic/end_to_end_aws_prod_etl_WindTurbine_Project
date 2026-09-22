# Glue "NETWORK" connection: puts the job inside our VPC and subnet.
# No password stored; this is just a network placement, not a JDBC config.
resource "aws_glue_connection" "vpc_network" {
  name            = "${var.project_name}-vpc-network"
  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = [var.security_group_id]
    subnet_id              = var.subnet_id
  }
}

# Log group for the job's continuous CloudWatch logs.
# Name must start with /aws-glue/ to be covered by AWSGlueServiceRole.
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws-glue/jobs/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# The Glue job itself.
resource "aws_glue_job" "pipeline" {
  name              = "${var.project_name}-pipeline"
  role_arn          = aws_iam_role.glue_job.arn
  glue_version      = "5.0"
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.timeout_minutes
  max_retries       = 0

  execution_property {
    # 1 means never overlap runs. The pipeline replaces tables with
    # if_exists="replace", so overlapping runs would corrupt output.
    max_concurrent_runs = 1
  }

  command {
    name            = "glueetl"
    script_location = var.entrypoint_s3_uri
    python_version  = "3"
  }

  # Arguments passed to aws_entrypoint.py at each run.
  # Note: --additional-python-modules tells Glue to pip-install the
  # wheels we uploaded before running our script.
  default_arguments = {
    "--job-language"                     = "python"
    "--data_bucket"                      = var.data_lake_bucket
    "--code_s3_uri"                      = var.code_s3_uri
    "--secret_name"                      = var.db_secret_name
    "--additional-python-modules"        = var.python_modules
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue.name
  }

  connections = [aws_glue_connection.vpc_network.name]
  tags        = var.tags
}
