variable "scripts_bucket" {
  type = string
}

# dropin_dir: absolute path to the aws_dropin folder on disk.
# The environment root fills this in from local.dropin_dir.
variable "dropin_dir" {
  description = "Path to the repo's aws_dropin folder"
  type        = string
}
