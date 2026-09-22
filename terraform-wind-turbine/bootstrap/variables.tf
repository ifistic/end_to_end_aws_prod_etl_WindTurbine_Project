# Inputs to the bootstrap config. Defaults are set so you can run
# `terraform apply` with no options and get sensible values.

# aws_region: which AWS region to create the state bucket in.
# Match this to the region you'll deploy the pipeline in.
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

# project_name: shows up in the state bucket name and every tag.
# If you change it, every resource across the whole project renames.
variable "project_name" {
  type    = string
  default = "wind-turbine-pipeline"
}

# environments: list of environment names bootstrap will write a
# backend.hcl file for. Add "staging" or "prod" here later if you
# make more environment folders.
variable "environments" {
  description = "Environments to write a backend.hcl for"
  type        = list(string)
  default     = ["dev"]
}

# allow_state_bucket_destroy: safety catch.
# The state bucket keeps history of every terraform apply you've ever
# done. Wiping it by accident would be very bad. So `terraform destroy`
# in bootstrap/ refuses to empty and delete the bucket unless you
# explicitly set this to true.
variable "allow_state_bucket_destroy" {
  description = "Set true only when tearing down for good"
  type        = bool
  default     = false
}
