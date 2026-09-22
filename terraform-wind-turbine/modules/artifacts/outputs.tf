# S3 URIs the glue_pipeline module passes to the Glue job.
output "code_s3_uri" {
  value = "s3://${var.scripts_bucket}/${aws_s3_object.app.key}"
}

output "entrypoint_s3_uri" {
  value = "s3://${var.scripts_bucket}/${aws_s3_object.entrypoint.key}"
}

# python_modules: comma-separated list of every wheel URI, in a stable order.
# Glue's --additional-python-modules takes this and pip-installs them at
# job start.
output "python_modules" {
  description = "Comma-separated wheel URIs for Glue's --additional-python-modules"
  value       = join(",", [for k in sort(keys(aws_s3_object.wheels)) : "s3://${var.scripts_bucket}/${aws_s3_object.wheels[k].key}"])
}

# build_dir: the orchestration module needs this too so it knows where
# to put its Lambda zip files.
output "build_dir" {
  value = local.build_dir
}
