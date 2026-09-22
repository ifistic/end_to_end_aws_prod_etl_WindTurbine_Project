# Central SNS topic for pipeline alerts. Publishers include:
#   - EventBridge rule for Glue job state changes
#   - Lambda "on failure" destination
#   - ingest_trigger Lambda when a file is quarantined
# One optional email subscription.

# Look up our own AWS account ID; we use it in the topic policy.
data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "pipeline_alerts" {
  name = "${var.project_name}-alerts"
  tags = var.tags
}

# Topic policy: who is allowed to publish and subscribe.
# - The account owner can do anything.
# - EventBridge and CloudWatch (services) can publish, but only from
#   this AWS account (aws:SourceAccount condition).
resource "aws_sns_topic_policy" "pipeline_alerts" {
  arn = aws_sns_topic.pipeline_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountOwner"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = ["sns:Publish", "sns:Subscribe", "sns:GetTopicAttributes"]
        Resource  = aws_sns_topic.pipeline_alerts.arn
      },
      {
        Sid       = "EventBridgeAndAlarms"
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "cloudwatch.amazonaws.com"] }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.pipeline_alerts.arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      }
    ]
  })
}

# Optional email subscription. AWS sends a "confirm subscription" email
# the first time this is created; you have to click the link to activate.
resource "aws_sns_topic_subscription" "alert_email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
