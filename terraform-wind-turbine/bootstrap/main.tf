# Creates the S3 bucket that holds Terraform state for every environment,
# and writes a backend.hcl file into each environment folder so `make init`
# knows where the state lives. Runs once, before any environment is applied.

# data source: no resource created, just a lookup. This gives us the AWS
# account ID, which we put in the bucket name to keep it globally unique.
data "aws_caller_identity" "current" {}

# The state bucket itself. Naming pattern:
#   <project>-tfstate-<account-id>-<region>
# Bucket names must be globally unique across all of AWS, so including the
# account ID and region avoids clashes with anyone else's project.
resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # force_destroy: normally FALSE (protected), so a stray `terraform destroy`
  # can't wipe your state. Only TRUE when you explicitly set the variable
  # because you're really tearing everything down.
  force_destroy = var.allow_state_bucket_destroy
}

# Versioning: keeps every previous version of every state file. If you
# somehow corrupt state, you can roll back to yesterday's version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest with AES256 (S3-managed keys). Free, and turns off
# a bunch of security warnings.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all forms of public access. State files can contain secrets
# (RDS passwords, IAM keys), so they must never be publicly reachable.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: deny any request that isn't over HTTPS. Belt and braces
# on top of the encryption at rest.
resource "aws_s3_bucket_policy" "state_tls_only" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  # Terraform sometimes tries to write the policy before public access is
  # blocked, which S3 rejects. depends_on forces the correct order.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# For each environment in var.environments, write a small backend.hcl file
# into that environment's folder. terraform init reads it to know:
# which bucket, which key path, which region. Result: each environment
# has its own state file at <bucket>/<project>/<env>/terraform.tfstate.
resource "local_file" "backend_config" {
  for_each = toset(var.environments)
  filename = "${path.module}/../environments/${each.key}/backend.hcl"
  content  = <<-EOT
    bucket       = "${aws_s3_bucket.state.bucket}"
    key          = "${var.project_name}/${each.key}/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
