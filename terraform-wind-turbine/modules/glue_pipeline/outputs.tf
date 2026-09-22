output "job_name" {
  value = aws_glue_job.pipeline.name
}

output "job_arn" {
  value = aws_glue_job.pipeline.arn
}
