# All the Lambda-side resources. Everything counts on var.enabled.

locals {
  instances     = var.enabled ? 1 : 0
  function_name = "${var.project_name}-snowflake-loader"
  layer_zip     = "${var.build_dir}/snowflake_layer.zip"
}

# Secret holding Snowflake connection details, read by the Lambda at runtime.
resource "aws_secretsmanager_secret" "snowflake" {
  count                   = local.instances
  name                    = "${var.project_name}/${var.environment}/snowflake"
  description             = "Key-pair credentials for the Snowflake loader Lambda"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "snowflake" {
  count     = local.instances
  secret_id = aws_secretsmanager_secret.snowflake[0].id
  secret_string = jsonencode({
    account     = var.account
    user        = var.user
    private_key = file(pathexpand(var.private_key_path))
    role        = var.role
    warehouse   = var.warehouse
    database    = var.database
    schema      = var.schema
  })
}

# Own IAM role: reads only the Snowflake secret, publishes to SNS on failure.
resource "aws_iam_role" "loader" {
  count = local.instances
  name  = "${var.project_name}-snowflake-loader-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "loader_logs" {
  count      = local.instances
  role       = aws_iam_role.loader[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "loader" {
  count = local.instances
  name  = "read-secret-publish-alerts"
  role  = aws_iam_role.loader[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.snowflake[0].arn
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

# Lambda layer with the snowflake-connector-python package.
# BUILD_SNOWFLAKE_LAYER=1 bash build.sh must have run first.
resource "aws_lambda_layer_version" "snowflake" {
  count               = local.instances
  layer_name          = "${var.project_name}-snowflake-connector"
  filename            = local.layer_zip
  source_code_hash    = fileexists(local.layer_zip) ? filebase64sha256(local.layer_zip) : null
  compatible_runtimes = ["python3.12"]

  lifecycle {
    precondition {
      condition     = fileexists(local.layer_zip)
      error_message = "Snowflake layer missing. Run: BUILD_SNOWFLAKE_LAYER=1 bash aws_dropin/scripts/build.sh"
    }
  }
}

# Zip the loader Lambda source.
data "archive_file" "loader" {
  type        = "zip"
  source_dir  = "${var.dropin_dir}/lambda/snowflake_loader"
  output_path = "${var.build_dir}/lambda_snowflake_loader.zip"
  excludes    = ["__pycache__"]
}

resource "aws_cloudwatch_log_group" "loader" {
  name              = "/${var.project_name}/lambda/snowflake_loader"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "snowflake_loader" {
  count            = local.instances
  function_name    = local.function_name
  role             = aws_iam_role.loader[0].arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.loader.output_path
  source_code_hash = data.archive_file.loader.output_base64sha256
  layers           = [aws_lambda_layer_version.snowflake[0].arn]
  timeout          = 300
  memory_size      = 512

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.loader.name
  }

  environment {
    variables = { SNOWFLAKE_SECRET_NAME = aws_secretsmanager_secret.snowflake[0].name }
  }
  tags = var.tags
}

resource "aws_lambda_function_event_invoke_config" "snowflake_alerts" {
  count                  = local.instances
  function_name          = aws_lambda_function.snowflake_loader[0].function_name
  maximum_retry_attempts = 2
  destination_config {
    on_failure {
      destination = var.sns_topic_arn
    }
  }
}

# EventBridge rule: fires when the Glue job SUCCEEDS.
resource "aws_cloudwatch_event_rule" "glue_succeeded" {
  count = local.instances
  name  = "${var.project_name}-glue-succeeded"
  event_pattern = jsonencode({
    source        = ["aws.glue"]
    "detail-type" = ["Glue Job State Change"]
    detail        = { jobName = [var.glue_job_name], state = ["SUCCEEDED"] }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "snowflake_loader" {
  count = local.instances
  rule  = aws_cloudwatch_event_rule.glue_succeeded[0].name
  arn   = aws_lambda_function.snowflake_loader[0].arn
}

resource "aws_lambda_permission" "snowflake_loader" {
  count         = local.instances
  statement_id  = "AllowEventBridge-glue-succeeded"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snowflake_loader[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.glue_succeeded[0].arn
}

# Cleanup helper on destroy.
resource "terraform_data" "leftover_log_group" {
  input = { region = var.aws_region, group = "/aws/lambda/${local.function_name}" }

  provisioner "local-exec" {
    when    = destroy
    command = "aws logs delete-log-group --region ${self.input.region} --log-group-name ${self.input.group} >/dev/null 2>&1 || true"
  }
}
