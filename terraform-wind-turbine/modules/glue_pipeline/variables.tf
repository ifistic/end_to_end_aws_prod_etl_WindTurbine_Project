variable "project_name" {
  type = string
}

variable "data_lake_bucket" {
  type = string
}

variable "data_lake_arn" {
  type = string
}

variable "scripts_arn" {
  type = string
}

variable "db_secret_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "entrypoint_s3_uri" {
  type = string
}

variable "code_s3_uri" {
  type = string
}

variable "python_modules" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "worker_type" {
  type    = string
  default = "G.1X"
}

# Glue's minimum is 2. Our pipeline runs single-node on the driver
# because the repo reads and writes local paths, so extra workers
# would sit idle.
variable "number_of_workers" {
  description = "Glue minimum is 2; the repo runs single-node on the driver"
  type        = number
  default     = 2
}

variable "timeout_minutes" {
  type    = number
  default = 60
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
