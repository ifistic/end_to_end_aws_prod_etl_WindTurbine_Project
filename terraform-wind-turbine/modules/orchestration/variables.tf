variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "dropin_dir" {
  type = string
}

variable "build_dir" {
  type = string
}

variable "data_lake_bucket" {
  type = string
}

variable "data_lake_arn" {
  type = string
}

variable "glue_job_name" {
  type = string
}

variable "glue_job_arn" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

# rerun_check_schedule: how often the post_run Lambda checks for
# queued reruns as a safety net. rate(1 hour) is fine for dev.
variable "rerun_check_schedule" {
  type    = string
  default = "rate(1 hour)"
}

# cleanup_shared_glue_log_groups: on destroy, also delete Glue's
# account-wide default log groups. Only enable if nothing else in
# this account uses Glue.
variable "cleanup_shared_glue_log_groups" {
  description = "On destroy, also delete Glue's account-wide /aws-glue/jobs/* groups"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
