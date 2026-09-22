# The code bucket: app.zip, entrypoint, wheels, EMR bootstrap.
# Terraform uploads to this bucket from the artifacts module.

resource "aws_s3_bucket" "glue_scripts" {
  bucket        = "${var.project_name}-glue-scripts-${random_id.bucket_suffix.hex}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "glue_scripts" {
  bucket                  = aws_s3_bucket.glue_scripts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
