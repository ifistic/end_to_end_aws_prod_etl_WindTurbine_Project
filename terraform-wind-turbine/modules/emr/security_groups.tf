# EMR needs three managed security groups: master, core, service-access.
# EMR itself edits their rules at cluster creation, so:
#   - lifecycle ignores rule drift (Terraform won't try to undo EMR's edits)
#   - revoke_rules_on_delete clears cross-references between the SGs so
#     `terraform destroy` can actually delete them.
# Without those, destroy fails with "resource has a dependent object".

resource "aws_security_group" "emr" {
  for_each               = var.enabled ? toset(["master", "core", "service-access"]) : toset([])
  name                   = "${var.project_name}-emr-${each.key}"
  description            = "EMR managed ${each.key} security group"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-emr-${each.key}" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}
