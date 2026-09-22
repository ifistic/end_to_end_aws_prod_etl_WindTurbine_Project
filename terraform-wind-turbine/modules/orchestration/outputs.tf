output "ingest_trigger_function" {
  value = aws_lambda_function.ingest_trigger.function_name
}

output "post_run_function" {
  value = aws_lambda_function.post_run.function_name
}
