# All settings for one environment, in one file. Defaults are dev-safe.
# Override in terraform.tfvars.

# ---------- core ----------
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "wind-turbine-pipeline"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "wind-turbine-pipeline"
    ManagedBy = "terraform"
  }
}

# ---------- network ----------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# ---------- database ----------
variable "db_name" {
  type    = string
  default = "wind_turbine_db"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

# ---------- glue ----------
variable "glue_worker_type" {
  type    = string
  default = "G.1X"
}

variable "glue_number_of_workers" {
  type    = number
  default = 2
}

# ---------- ops ----------
variable "alert_email" {
  description = "Email that gets pipeline alerts; empty means no subscription"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "cleanup_shared_glue_log_groups" {
  description = "On destroy, also delete Glue's account-wide default log groups"
  type        = bool
  default     = false
}

variable "create_uploader_access_key" {
  type    = bool
  default = true
}

# ---------- optional: EMR ----------
variable "enable_emr" {
  description = "Adds NAT gateway (hourly cost) plus EMR roles and security groups"
  type        = bool
  default     = false
}

# ---------- optional: Snowflake ----------
variable "enable_snowflake" {
  type    = bool
  default = false
}

variable "snowflake_account" {
  type    = string
  default = ""
}

variable "snowflake_private_key_path" {
  type    = string
  default = ""
}

variable "snowflake_iam_user_arn" {
  type    = string
  default = ""
}

variable "snowflake_external_id" {
  type    = string
  default = ""
}

variable "create_bastion" {
  type    = bool
  default = false
}

variable "bastion_key_name" {
  type    = string
  default = ""
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
