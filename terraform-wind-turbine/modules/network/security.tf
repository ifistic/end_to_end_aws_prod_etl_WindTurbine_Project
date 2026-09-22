# One security group shared by RDS, Glue and the interface endpoints.
# All rules are "from the same security group", so anything inside the
# SG can reach anything else inside it, and nothing outside can reach in.

resource "aws_security_group" "data_pipeline" {
  name        = "${var.project_name}-sg"
  description = "Allows Glue jobs to reach RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id
  tags        = var.tags
}

# Glue -> RDS on 5432.
resource "aws_security_group_rule" "postgres_self_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data_pipeline.id
  source_security_group_id = aws_security_group.data_pipeline.id
}

# Glue needs all TCP ports open inside its own security group; this
# also covers HTTPS from Glue to the interface endpoints below.
resource "aws_security_group_rule" "glue_self_all_tcp" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data_pipeline.id
  source_security_group_id = aws_security_group.data_pipeline.id
}

# All egress open. Terraform-created SGs default to no egress, so
# without this Glue can't reach anything.
resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.data_pipeline.id
}
