# Both Lambdas: ingest_trigger and post_run.

locals {
  lambda_names = {
    ingest_trigger = "${var.project_name}-ingest-trigger"
    post_run       = "${var.project_name}-post-run"
  }
}

# Zip each Lambda's source folder on the fly.
data "archive_file" "lambda" {
  for_each    = local.lambda_names
  type        = "zip"
  source_dir  = "${var.dropin_dir}/lambda/${each.key}"
  output_path = "${var.build_dir}/lambda_${each.key}.zip"
  excludes    = ["__pycache__"]
}

# Terraform-owned log groups, so `destroy` cleans them up.
# Without these, Lambda auto-creates /aws/lambda/... groups on first run.
resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.lambda_names
  name              = "/${var.project_name}/lambda/${each.key}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ingest_trigger: fires when a file lands in s3://.../landing/.
# It validates the file, unpacks to raw/, and starts the Glue job.
resource "aws_lambda_function" "ingest_trigger" {
  function_name    = local.lambda_names.ingest_trigger
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda["ingest_trigger"].output_path
  source_code_hash = data.archive_file.lambda["ingest_trigger"].output_base64sha256
  timeout          = 300
  memory_size      = 1024

  # 2 GB /tmp so we can unpack a big data.zip in memory.
  ephemeral_storage {
    size = 2048
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda["ingest_trigger"].name
  }

  environment {
    variables = {
      GLUE_JOB_NAME = var.glue_job_name
      SNS_TOPIC_ARN = var.sns_topic_arn
    }
  }
  tags = var.tags
}

# post_run: fires when the Glue job finishes (any state) and hourly.
# If files landed during the run, it starts one more run to pick them up.
resource "aws_lambda_function" "post_run" {
  function_name    = local.lambda_names.post_run
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda["post_run"].output_path
  source_code_hash = data.archive_file.lambda["post_run"].output_base64sha256
  timeout          = 30

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda["post_run"].name
  }

  environment {
    variables = {
      DATA_BUCKET   = var.data_lake_bucket
      GLUE_JOB_NAME = var.glue_job_name
    }
  }
  tags = var.tags
}

# Send Lambda failures to SNS after 2 retries.
resource "aws_lambda_function_event_invoke_config" "alerts" {
  for_each = {
    ingest_trigger = aws_lambda_function.ingest_trigger.function_name
    post_run       = aws_lambda_function.post_run.function_name
  }
  function_name          = each.value
  maximum_retry_attempts = 2
  destination_config {
    on_failure {
      destination = var.sns_topic_arn
    }
  }
}
