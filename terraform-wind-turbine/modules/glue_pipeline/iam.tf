# Least-privilege IAM role for the Glue job.
# - Full read/write on the data lake bucket
# - Read-only on the scripts bucket (app.zip, wheels, entrypoint)
# - Read on the DB credentials secret
# - EC2 permissions needed to attach an ENI to our VPC subnet

resource "aws_iam_role" "glue_job" {
  name = "${var.project_name}-glue-job-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "glue.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

# AWSGlueServiceRole: AWS-managed policy Glue itself expects.
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project_name}-glue-s3-access"
  role = aws_iam_role.glue_job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DataLakeReadWrite"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.data_lake_arn, "${var.data_lake_arn}/*"]
      },
      {
        Sid      = "ScriptsReadOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.scripts_arn, "${var.scripts_arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "glue_secrets_access" {
  name = "${var.project_name}-glue-secrets-access"
  role = aws_iam_role.glue_job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadDbCredentials"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

# EC2 permissions Glue needs to attach a network interface to our VPC.
# These actions don't support resource-level restrictions in IAM,
# hence Resource = "*".
resource "aws_iam_role_policy" "glue_vpc_access" {
  name = "${var.project_name}-glue-vpc-access"
  role = aws_iam_role.glue_job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GlueVpcEni"
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcAttribute"
      ]
      Resource = "*"
    }]
  })
}
