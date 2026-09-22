# Small helper that runs a shell command on `terraform destroy`.
# It removes log groups that AWS auto-created outside Terraform's
# knowledge (from runs before we set logging_config, or Glue's
# shared /aws-glue/jobs/* defaults if the operator opts in).

resource "terraform_data" "leftover_log_groups" {
  input = {
    region = var.aws_region
    groups = concat(
      [for n in values(local.lambda_names) : "/aws/lambda/${n}"],
      var.cleanup_shared_glue_log_groups ? ["/aws-glue/jobs/output", "/aws-glue/jobs/error", "/aws-glue/jobs/logs-v2"] : []
    )
  }

  provisioner "local-exec" {
    when    = destroy
    command = "for g in ${join(" ", self.input.groups)}; do aws logs delete-log-group --region ${self.input.region} --log-group-name \"$g\" >/dev/null 2>&1 && echo \"deleted $g\" || true; done"
  }
}
