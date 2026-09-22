# Two IAM roles for EMR:
#   emr_service: the role EMR itself assumes to manage the cluster.
#   emr_ec2:     the role attached to the EC2 instances in the cluster.

locals {
  instances = var.enabled ? 1 : 0
}

# ---------- service role ----------
resource "aws_iam_role" "emr_service" {
  count = local.instances
  name  = "${var.project_name}-emr-service"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "elasticmapreduce.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "emr_service" {
  count      = local.instances
  role       = aws_iam_role.emr_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# The AWS-managed policy above only allows PassRole for the default
# EMR_EC2_DefaultRole. We use our own EC2 role, so add an extra
# PassRole allowance for it.
resource "aws_iam_role_policy" "emr_service_pass_role" {
  count = local.instances
  name  = "pass-instance-role"
  role  = aws_iam_role.emr_service[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = aws_iam_role.emr_ec2[0].arn
      Condition = { StringLike = { "iam:PassedToService" = "ec2.amazonaws.com*" } }
    }]
  })
}

# ---------- EC2 (worker) role ----------
resource "aws_iam_role" "emr_ec2" {
  count = local.instances
  name  = "${var.project_name}-emr-ec2"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "emr_ec2" {
  count = local.instances
  name  = "pipeline-access"
  role  = aws_iam_role.emr_ec2[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DataLake"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.data_lake_arn, "${var.data_lake_arn}/*"]
      },
      {
        Sid      = "Scripts"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.scripts_arn, "${var.scripts_arn}/*"]
      },
      {
        Sid      = "DbSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn
      }
    ]
  })
}

# EC2 needs an instance profile (a wrapper around the role) to attach it.
resource "aws_iam_instance_profile" "emr_ec2" {
  count = local.instances
  name  = "${var.project_name}-emr-ec2"
  role  = aws_iam_role.emr_ec2[0].name
  tags  = var.tags
}
