variable "project_name" {
  type = string
}

variable "data_lake_arn" {
  type = string
}

# create_access_key: whether Terraform manages the access key.
# true means the secret is stored inside your Terraform state file,
# which is fine because state is already encrypted in S3. False lets
# you create the key manually if you'd rather not have it in state.
variable "create_access_key" {
  description = "Create the access key in Terraform (secret is stored in state)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
