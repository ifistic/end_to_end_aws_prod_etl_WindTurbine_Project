# IAM user for downloads_to_s3.py on your laptop.
# Can ONLY write to s3://<data-lake>/landing/. Cannot read, cannot
# touch other prefixes, cannot delete anything.

resource "aws_iam_user" "uploader" {
  name = "${var.project_name}-downloads-uploader"
  # force_destroy: also removes any access keys created outside Terraform
  # (e.g. by clicking around in the console). Prevents "user has keys"
  # errors on destroy.
  force_destroy = true
  tags          = var.tags
}

resource "aws_iam_user_policy" "uploader" {
  name = "put-landing-only"
  user = aws_iam_user.uploader.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${var.data_lake_arn}/landing/*"
    }]
  })
}

# Terraform-managed access key. Configure your laptop with:
#   aws configure --profile turbine-uploader
# using the values from `terraform output uploader_access_key_id` and
# `terraform output -raw uploader_secret_access_key`.
resource "aws_iam_access_key" "uploader" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.uploader.name
}
