# The data lake bucket, used by every prefix:
#   landing/     files uploaded from your laptop
#   archive/     originals kept after successful processing
#   quarantine/  files rejected for bad headers
#   raw/         validated CSVs input to Glue
#   control/     rerun marker
#   curated/     bronze/silver/gold output from Glue
#   emr-logs/    only if EMR is used

# random_id gives the bucket name a suffix. Bucket names are globally
# unique across all of AWS, so anything without a random suffix would
# fight with someone else's project.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-${random_id.bucket_suffix.hex}"
  # force_destroy = true so `terraform destroy` empties the bucket first.
  # Without this you'd get "bucket not empty" and have to clean it manually.
  force_destroy = true
  tags          = var.tags
}

# Versioning: keep every version of every object. Cheap safety net.
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with AES256 (free, no KMS to manage).
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access.
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: after 30 days, move raw/ and bronze/ to Infrequent Access
# storage class (cheaper). Audit-trail data rarely gets read again.
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "raw-to-ia"
    status = "Enabled"
    filter {
      and {
        prefix = "raw/"
      }
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "bronze-to-ia"
    status = "Enabled"
    filter {
      prefix = "curated/latest/bronze/"
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Sends S3 object-created events to EventBridge (the orchestration
# module has an EventBridge rule watching for landing/).
resource "aws_s3_bucket_notification" "data_lake_eventbridge" {
  bucket      = aws_s3_bucket.data_lake.id
  eventbridge = true
}
