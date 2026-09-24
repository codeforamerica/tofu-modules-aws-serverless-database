module "database" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 10.0"

  name                   = local.prefix
  create_db_subnet_group = true
  db_subnet_group_name   = local.prefix
  engine                 = "aurora-${var.engine}"
  engine_version         = var.replica.enabled ? local.engine_version : var.engine_version
  engine_mode            = "provisioned"
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.database.arn
  master_username        = "root"
  subnets                = var.subnets
  copy_tags_to_snapshot  = true
  snapshot_identifier    = var.snapshot_identifier
  deletion_protection    = !var.force_delete
  enable_http_endpoint   = var.enable_data_api

  cluster_parameter_group = length(local.cluster_parameters) > 0 ? {
    family     = data.aws_rds_engine_version.this.parameter_group_family
    parameters = local.cluster_parameters
  } : null

  iam_role_name                       = "${local.short_prefix}-db-mon"
  iam_role_use_name_prefix            = true
  security_group_name                 = "${local.prefix}-database-"
  security_group_use_name_prefix      = true
  iam_database_authentication_enabled = var.iam_authentication
  backup_retention_period             = local.auto_backup_retention

  # Rules live in security_group_rules.tf, not here - keeps us off
  # whatever rule resource this module happens to use internally.
  vpc_id = var.vpc_id

  manage_master_user_password                            = true
  manage_master_user_password_rotation                   = var.password_rotation_frequency > 0
  master_user_password_rotation_automatically_after_days = var.password_rotation_frequency

  cloudwatch_log_group_kms_key_id               = var.logging_key_arn
  cloudwatch_log_group_retention_in_days        = 7
  cluster_performance_insights_kms_key_id       = var.logging_key_arn
  cluster_performance_insights_enabled          = true
  cluster_performance_insights_retention_period = 7

  # TODO: Create a database KMS key
  master_user_secret_kms_key_id = var.secrets_key_arn

  cluster_monitoring_interval = 60

  apply_immediately         = var.apply_immediately
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${local.prefix}-final"

  serverlessv2_scaling_configuration = {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # TODO: Configure log groups.
  enabled_cloudwatch_logs_exports = [for l in flatten([
    "instance",
    "postgresql",
    var.iam_authentication ? ["iam-db-auth-error"] : []
  ]) : l if contains(data.aws_rds_engine_version.this.exportable_log_types, l)]

  cluster_instance_class = "db.serverless"
  instances = {
    for i in range(var.instances) : (i + 1) => {}
  }

  cluster_tags = var.configure_aws_backup ? { "aws-backup/rds" = "daily" } : {}
  tags         = local.tags
}
