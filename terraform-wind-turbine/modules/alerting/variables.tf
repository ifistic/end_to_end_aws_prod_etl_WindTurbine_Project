variable "project_name" {
  type = string
}

variable "alert_email" {
  description = "Email to subscribe; empty means no subscription"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
