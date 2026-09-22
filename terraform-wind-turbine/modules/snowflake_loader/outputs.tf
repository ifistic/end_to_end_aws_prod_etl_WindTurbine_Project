# STORAGE_AWS_ROLE_ARN for setup.sql. Null when Snowflake IDs aren't set yet.
output "s3_role_arn" {
  description = "Use as STORAGE_AWS_ROLE_ARN in the Snowflake storage integration"
  value       = try(aws_iam_role.snowflake_s3[0].arn, null)
}
