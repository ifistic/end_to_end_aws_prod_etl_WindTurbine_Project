variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage_gb" {
  type = number
}

# engine_version: pin the PostgreSQL version. Bumping here upgrades RDS
# on the next apply.
variable "engine_version" {
  type    = string
  default = "18.1"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
