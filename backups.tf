resource "aws_backup_vault" "cross_region_vault" {
  for_each = var.configure_aws_backup && var.backup_replica_region != null ? toset(["this"]) : toset([])

  force_destroy = var.force_delete
  name          = join("-", compact([var.backup_namespace, var.environment, var.project, var.service, "replica"]))
  region        = var.backup_replica_region
  kms_key_arn   = aws_kms_replica_key.replica["this"].arn

  tags = var.tags
}

module "backup" {
  for_each = var.configure_aws_backup ? toset(["this"]) : toset([])
  source   = "cloudposse/backup/aws"
  version  = ">= 1.1.1"

  namespace   = var.backup_namespace
  stage       = var.environment
  name        = var.project
  attributes  = var.service != "" ? [var.service] : []
  kms_key_arn = aws_kms_key.backups["this"].arn

  vault_enabled    = true
  iam_role_enabled = true
  plan_enabled     = true

  selection_tags = [
    {
      type  = "STRINGEQUALS"
      key   = "aws-backup/rds"
      value = "daily"
    }
  ]

  rules = [for schedule in var.backup_schedules : {
    name              = join("-", [local.prefix, schedule.name])
    schedule          = schedule.schedule
    start_window      = schedule.start_window
    completion_window = schedule.completion_window

    lifecycle = {
      delete_after = schedule.retention
    }

    copy_action = {
      destination_vault_arn = var.backup_replica_region != null ? aws_backup_vault.cross_region_vault["this"].arn : null
      lifecycle = {
        delete_after = schedule.retention
      }
    }
  }]

  tags = var.tags
}
