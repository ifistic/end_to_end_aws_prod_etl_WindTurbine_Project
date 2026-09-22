# enabled: master switch. When false, nothing in this module is created.
variable "enabled" {
  type    = bool
  default = false
}

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

# pipeline_security_group_id: the shared SG that RDS lives in.
# Adding it to the EMR master lets EMR reach RDS on port 5432.
variable "pipeline_security_group_id" {
  description = "Added to the master node so it can reach RDS"
  type        = string
}

variable "data_lake_arn" {
  type = string
}

variable "scripts_arn" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
