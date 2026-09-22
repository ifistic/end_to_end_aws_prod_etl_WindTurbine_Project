# enabled: master switch. When false, the module creates nothing.
variable "enabled" {
  description = "Deploy the loader Lambda (needs build.sh with BUILD_SNOWFLAKE_LAYER=1)"
  type        = bool
  default     = false
}

variable "project_name" {
  type = string
}

variable "environment" {
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

variable "data_lake_arn" {
  type = string
}

variable "glue_job_name" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

# Snowflake connection details, stored in Secrets Manager.
variable "account" {
  type    = string
  default = ""
}

variable "private_key_path" {
  description = "Unencrypted PKCS8 key for the loader user (loader_key.p8)"
  type        = string
  default     = ""
}

variable "user" {
  type    = string
  default = "WIND_TURBINE_LOADER"
}

variable "role" {
  type    = string
  default = "WIND_TURBINE_LOADER_ROLE"
}

variable "warehouse" {
  type    = string
  default = "WIND_TURBINE_WH"
}

variable "database" {
  type    = string
  default = "WIND_TURBINE"
}

variable "schema" {
  type    = string
  default = "ANALYTICS"
}

# iam_user_arn and external_id: filled in AFTER you run setup.sql in
# Snowflake. DESC INTEGRATION prints them.
variable "iam_user_arn" {
  description = "STORAGE_AWS_IAM_USER_ARN from DESC INTEGRATION"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "STORAGE_AWS_EXTERNAL_ID from DESC INTEGRATION"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
