module "database" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.8"

  name                   = local.prefix
  create_db_subnet_group = true
  db_subnet_group_name   = local.prefix
  engine                 = "aurora-${var.engine}"
  engine_version         = var.engine_version
  engine_mode            = "provisioned"
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.database.arn
  master_username        = "root"
  subnets                = var.subnets
  copy_tags_to_snapshot  = true
  snapshot_identifier    = var.snapshot_identifier
  deletion_protection    = !var.force_delete
  enable_http_endpoint   = var.enable_data_api

  create_db_cluster_parameter_group     = length(var.cluster_parameters) > 0
  db_cluster_parameter_group_family     = data.aws_rds_engine_version.this.parameter_group_family
  db_cluster_parameter_group_parameters = var.cluster_parameters

  iam_role_name                       = "${local.short_prefix}-db-mon"
  iam_role_use_name_prefix            = true
  security_group_name                 = "${local.prefix}-database-"
  security_group_use_name_prefix      = true
  iam_database_authentication_enabled = var.iam_authentication
  backup_retention_period             = var.backup_retention_period

  vpc_id               = var.vpc_id
  security_group_rules = local.security_group_rules

  manage_master_user_password                            = true
  manage_master_user_password_rotation                   = var.password_rotation_frequency > 0
  master_user_password_rotation_automatically_after_days = var.password_rotation_frequency

  cloudwatch_log_group_kms_key_id        = var.logging_key_arn
  cloudwatch_log_group_retention_in_days = 7
  performance_insights_kms_key_id        = var.logging_key_arn
  performance_insights_enabled           = true
  performance_insights_retention_period  = 7

  # TODO: Create a database KMS key
  master_user_secret_kms_key_id = var.secrets_key_arn

  monitoring_interval = 60

  apply_immediately   = var.apply_immediately
  skip_final_snapshot = var.skip_final_snapshot
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

  instance_class = "db.serverless"
  instances = {
    for i in range(var.instances) : (i + 1) => {}
  }

  tags = var.tags
}
