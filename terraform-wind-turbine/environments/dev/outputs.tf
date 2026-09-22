# Values you can look up with `terraform output` or `make output`.
# Handy for scripts and for the local_agent uploader that runs on your laptop.

output "data_lake_bucket" {
  value = module.storage.data_lake_bucket
}

output "glue_scripts_bucket" {
  value = module.storage.scripts_bucket
}

output "rds_endpoint" {
  value = module.database.endpoint
}

output "db_credentials_secret_name" {
  value = module.database.secret_name
}

output "sns_alerts_topic_arn" {
  value = module.alerting.topic_arn
}

output "glue_pipeline_job_name" {
  value = module.glue_pipeline.job_name
}

# Uploader IAM credentials. secret_access_key is sensitive so it won't print
# unless you run `terraform output uploader_secret_access_key`.
output "uploader_access_key_id" {
  value = module.uploader.access_key_id
}

output "uploader_secret_access_key" {
  value     = module.uploader.secret_access_key
  sensitive = true
}

output "snowflake_s3_role_arn" {
  value = module.snowflake_loader.s3_role_arn
}

# emr_settings is null when EMR is disabled; the EMR launcher script checks
# for that and refuses to run if you haven't turned EMR on.
output "emr_settings" {
  value = module.emr.settings == null ? null : merge(module.emr.settings, {
    data_bucket    = module.storage.data_lake_bucket
    scripts_bucket = module.storage.scripts_bucket
    db_secret_name = module.database.secret_name
  })
}

output "bastion_public_ip" {
  value = module.network.bastion_public_ip
}
