# Role Snowflake's storage integration assumes to read curated/latest/.
# Only created once you fill in iam_user_arn and external_id (from
# DESC INTEGRATION in Snowflake).

locals {
  create_s3_role = var.iam_user_arn != ""
}

resource "aws_iam_role" "snowflake_s3" {
  count = local.create_s3_role ? 1 : 0
  name  = "${var.project_name}-snowflake-s3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.iam_user_arn }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:ExternalId" = var.external_id } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "snowflake_s3" {
  count = local.create_s3_role ? 1 : 0
  name  = "read-curated-latest"
  role  = aws_iam_role.snowflake_s3[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.data_lake_arn}/curated/latest/*"
      },
      {
        Effect    = "Allow"
        Action    = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource  = var.data_lake_arn
        Condition = { StringLike = { "s3:prefix" = ["curated/latest/*"] } }
      }
    ]
  })
}
