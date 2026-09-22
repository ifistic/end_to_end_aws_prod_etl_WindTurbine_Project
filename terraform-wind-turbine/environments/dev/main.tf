# Wires the modules together. Each module owns one concern; this file
# just passes outputs from one module in as inputs to the next.

locals {
  repo_root  = "${path.root}/../../.."
  dropin_dir = "${local.repo_root}/aws_dropin"
  name       = var.project_name
}

module "network" {
  source           = "../../modules/network"
  project_name     = local.name
  aws_region       = var.aws_region
  vpc_cidr         = var.vpc_cidr
  enable_nat       = var.enable_emr
  create_bastion   = var.create_bastion
  bastion_key_name = var.bastion_key_name
  my_ip_cidr       = var.my_ip_cidr
  tags             = var.tags
}

module "storage" {
  source       = "../../modules/storage"
  project_name = local.name
  tags         = var.tags
}

module "database" {
  source                  = "../../modules/database"
  project_name            = local.name
  environment             = var.environment
  db_name                 = var.db_name
  db_username             = var.db_username
  db_instance_class       = var.db_instance_class
  db_allocated_storage_gb = var.db_allocated_storage_gb
  private_subnet_ids      = module.network.private_subnet_ids
  security_group_id       = module.network.security_group_id
  tags                    = var.tags
}

module "alerting" {
  source       = "../../modules/alerting"
  project_name = local.name
  alert_email  = var.alert_email
  tags         = var.tags
}

module "artifacts" {
  source         = "../../modules/artifacts"
  scripts_bucket = module.storage.scripts_bucket
  dropin_dir     = local.dropin_dir
}

module "glue_pipeline" {
  source             = "../../modules/glue_pipeline"
  project_name       = local.name
  data_lake_bucket   = module.storage.data_lake_bucket
  data_lake_arn      = module.storage.data_lake_arn
  scripts_arn        = module.storage.scripts_arn
  db_secret_name     = module.database.secret_name
  db_secret_arn      = module.database.secret_arn
  entrypoint_s3_uri  = module.artifacts.entrypoint_s3_uri
  code_s3_uri        = module.artifacts.code_s3_uri
  python_modules     = module.artifacts.python_modules
  subnet_id          = module.network.private_subnet_ids[0]
  availability_zone  = module.network.private_subnet_azs[0]
  security_group_id  = module.network.security_group_id
  worker_type        = var.glue_worker_type
  number_of_workers  = var.glue_number_of_workers
  log_retention_days = var.log_retention_days
  tags               = var.tags
}

module "orchestration" {
  source                         = "../../modules/orchestration"
  project_name                   = local.name
  aws_region                     = var.aws_region
  dropin_dir                     = local.dropin_dir
  build_dir                      = module.artifacts.build_dir
  data_lake_bucket               = module.storage.data_lake_bucket
  data_lake_arn                  = module.storage.data_lake_arn
  glue_job_name                  = module.glue_pipeline.job_name
  glue_job_arn                   = module.glue_pipeline.job_arn
  sns_topic_arn                  = module.alerting.topic_arn
  log_retention_days             = var.log_retention_days
  cleanup_shared_glue_log_groups = var.cleanup_shared_glue_log_groups
  tags                           = var.tags
}

module "snowflake_loader" {
  source             = "../../modules/snowflake_loader"
  enabled            = var.enable_snowflake
  project_name       = local.name
  environment        = var.environment
  aws_region         = var.aws_region
  dropin_dir         = local.dropin_dir
  build_dir          = module.artifacts.build_dir
  data_lake_arn      = module.storage.data_lake_arn
  glue_job_name      = module.glue_pipeline.job_name
  sns_topic_arn      = module.alerting.topic_arn
  log_retention_days = var.log_retention_days
  account            = var.snowflake_account
  private_key_path   = var.snowflake_private_key_path
  iam_user_arn       = var.snowflake_iam_user_arn
  external_id        = var.snowflake_external_id
  tags               = var.tags
}

module "uploader" {
  source            = "../../modules/uploader"
  project_name      = local.name
  data_lake_arn     = module.storage.data_lake_arn
  create_access_key = var.create_uploader_access_key
  tags              = var.tags
}

module "emr" {
  source                     = "../../modules/emr"
  enabled                    = var.enable_emr
  project_name               = local.name
  vpc_id                     = module.network.vpc_id
  subnet_id                  = module.network.private_subnet_ids[0]
  pipeline_security_group_id = module.network.security_group_id
  data_lake_arn              = module.storage.data_lake_arn
  scripts_arn                = module.storage.scripts_arn
  db_secret_arn              = module.database.secret_arn
  tags                       = var.tags
}
