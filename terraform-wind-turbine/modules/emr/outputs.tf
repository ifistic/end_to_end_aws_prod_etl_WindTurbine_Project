# Bundle everything run_on_emr.sh needs into one object.
# Null when EMR is disabled, so the launcher script can refuse to run.
output "settings" {
  description = "Everything run_on_emr.sh needs (null when disabled)"
  value = var.enabled ? {
    service_role      = aws_iam_role.emr_service[0].name
    instance_profile  = aws_iam_instance_profile.emr_ec2[0].name
    subnet_id         = var.subnet_id
    master_sg         = aws_security_group.emr["master"].id
    core_sg           = aws_security_group.emr["core"].id
    service_access_sg = aws_security_group.emr["service-access"].id
    additional_sg     = var.pipeline_security_group_id
  } : null
}
