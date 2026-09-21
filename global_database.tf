resource "aws_rds_global_cluster" "this" {
  for_each = var.replica.enabled ? toset(["this"]) : toset([])

  # Promotes the existing primary cluster into a new global cluster rather
  # than setting global_cluster_identifier directly on it - the AWS API has
  # no ModifyDBCluster path for that, only CreateGlobalCluster with
  # source_db_cluster_identifier. See:
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster#new-global-cluster-from-existing-db-cluster
  global_cluster_identifier    = local.prefix
  source_db_cluster_identifier = module.database.cluster_arn
  force_destroy                = var.force_delete

  tags = local.tags
}

module "database_replica" {
  for_each = var.replica.enabled ? toset(["this"]) : toset([])

  depends_on = [module.database]

  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.8"

  providers = {
    aws = aws.replica
  }

  name                   = local.prefix
  create_db_subnet_group = true
  db_subnet_group_name   = local.prefix
  engine                 = "aurora-${var.engine}"
  engine_version         = local.engine_version
  engine_mode            = "provisioned"
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.database_replica["this"].arn
  subnets                = var.replica.subnets
  copy_tags_to_snapshot  = true
  deletion_protection    = !var.force_delete
  enable_http_endpoint   = var.enable_data_api

  is_primary_cluster        = false
  global_cluster_identifier = aws_rds_global_cluster.this["this"].id
  source_region             = data.aws_region.current.region

  create_db_cluster_parameter_group     = length(local.cluster_parameters) > 0
  db_cluster_parameter_group_family     = data.aws_rds_engine_version.this.parameter_group_family
  db_cluster_parameter_group_parameters = local.cluster_parameters

  iam_role_name                       = "${local.short_prefix}-db-mon-replica"
  iam_role_use_name_prefix            = true
  security_group_name                 = "${local.prefix}-database-replica-"
  security_group_use_name_prefix      = true
  iam_database_authentication_enabled = var.iam_authentication
  backup_retention_period             = local.auto_backup_retention

  vpc_id               = var.replica.vpc_id
  security_group_rules = local.replica_security_group_rules

  cloudwatch_log_group_kms_key_id        = var.replica.logging_key_arn
  cloudwatch_log_group_retention_in_days = 7
  performance_insights_kms_key_id        = var.replica.logging_key_arn
  performance_insights_enabled           = true
  performance_insights_retention_period  = 7

  monitoring_interval = 60

  apply_immediately         = var.apply_immediately
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${local.prefix}-replica-final"

  serverlessv2_scaling_configuration = {
    min_capacity = var.replica.min_capacity
    max_capacity = var.replica.max_capacity
  }

  enabled_cloudwatch_logs_exports = [for l in flatten([
    "instance",
    "postgresql",
    var.iam_authentication ? ["iam-db-auth-error"] : []
  ]) : l if contains(data.aws_rds_engine_version.this.exportable_log_types, l)]

  instance_class = "db.serverless"
  instances = {
    for i in range(var.replica.instances) : (i + 1) => {}
  }

  tags = local.replica_tags
}
