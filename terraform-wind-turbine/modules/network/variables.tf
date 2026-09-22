variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

# interface_endpoints: the AWS services Glue needs to reach privately.
# Glue runs inside our VPC with no internet, so these give it a path
# to Secrets Manager (for the DB password) and CloudWatch Logs.
variable "interface_endpoints" {
  description = "AWS services reachable privately from the subnets"
  type        = list(string)
  default     = ["secretsmanager", "logs"]
}

# enable_nat: whether to add an internet gateway + NAT gateway.
# NAT gateways cost about $30/month, so we only enable this when EMR
# is on (EMR's bootstrap needs internet to install packages from pip).
variable "enable_nat" {
  description = "Add IGW + NAT (needed by EMR bootstrap; bills hourly)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
