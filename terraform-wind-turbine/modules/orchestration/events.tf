# EventBridge rules that trigger the two Lambdas.

locals {
  # All Glue job states we consider "finished". Any of these fires post_run.
  glue_end_states = ["SUCCEEDED", "FAILED", "TIMEOUT", "STOPPED", "ERROR"]
}

# ---------- file landed in s3://.../landing/ ----------
resource "aws_cloudwatch_event_rule" "file_landed" {
  name = "${var.project_name}-file-landed"
  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [var.data_lake_bucket] }
      object = { key = [{ prefix = "landing/" }] }
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "file_landed" {
  rule = aws_cloudwatch_event_rule.file_landed.name
  arn  = aws_lambda_function.ingest_trigger.arn
}

# ---------- Glue job finished ----------
resource "aws_cloudwatch_event_rule" "glue_finished" {
  name = "${var.project_name}-glue-finished"
  event_pattern = jsonencode({
    source        = ["aws.glue"]
    "detail-type" = ["Glue Job State Change"]
    detail        = { jobName = [var.glue_job_name], state = local.glue_end_states }
  })
  tags = var.tags
}

# On finish, run post_run (rerun check) ...
resource "aws_cloudwatch_event_target" "glue_finished_post_run" {
  rule = aws_cloudwatch_event_rule.glue_finished.name
  arn  = aws_lambda_function.post_run.arn
}

# ... and send an email via SNS with a human-readable message.
resource "aws_cloudwatch_event_target" "glue_finished_sns" {
  rule = aws_cloudwatch_event_rule.glue_finished.name
  arn  = var.sns_topic_arn
  input_transformer {
    input_paths = {
      job   = "$.detail.jobName"
      run   = "$.detail.jobRunId"
      state = "$.detail.state"
      msg   = "$.detail.message"
    }
    input_template = "\"Wind turbine pipeline: Glue job <job> run <run> finished with state <state>. <msg>\""
  }
}

# ---------- hourly rerun safety net ----------
resource "aws_cloudwatch_event_rule" "rerun_check" {
  name                = "${var.project_name}-rerun-check"
  schedule_expression = var.rerun_check_schedule
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "rerun_check" {
  rule = aws_cloudwatch_event_rule.rerun_check.name
  arn  = aws_lambda_function.post_run.arn
}

# Permission for EventBridge to invoke each Lambda.
resource "aws_lambda_permission" "events" {
  for_each = {
    file_landed   = [aws_lambda_function.ingest_trigger.function_name, aws_cloudwatch_event_rule.file_landed.arn]
    glue_finished = [aws_lambda_function.post_run.function_name, aws_cloudwatch_event_rule.glue_finished.arn]
    rerun_check   = [aws_lambda_function.post_run.function_name, aws_cloudwatch_event_rule.rerun_check.arn]
  }
  statement_id  = "AllowEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value[0]
  principal     = "events.amazonaws.com"
  source_arn    = each.value[1]
}
