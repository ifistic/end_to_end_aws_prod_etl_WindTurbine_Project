output "data_lake_bucket" {
  value = aws_s3_bucket.data_lake.bucket
}

output "data_lake_arn" {
  value = aws_s3_bucket.data_lake.arn
}

output "scripts_bucket" {
  value = aws_s3_bucket.glue_scripts.bucket
}

output "scripts_arn" {
  value = aws_s3_bucket.glue_scripts.arn
}
