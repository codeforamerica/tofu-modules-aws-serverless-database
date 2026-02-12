module "cross_region_vault" {
  for_each = var.configure_aws_backup ? toset(["this"]) : toset([])
  source   = "cloudposse/backup/aws"
  version  = ">= 1.1.1"

  providers = {
    aws = aws.backup
  }

  namespace  = var.backup_namespace
  stage      = var.environment
  name       = var.project
  attributes = var.service != "" ? [var.service, "replica"] : ["replica"]

  vault_enabled    = true
  iam_role_enabled = true
  plan_enabled     = false
}

module "backup" {
  for_each = var.configure_aws_backup ? toset(["this"]) : toset([])
  source   = "cloudposse/backup/aws"
  version  = ">= 1.1.1"

  namespace  = var.backup_namespace
  stage      = var.environment
  name       = var.project
  attributes = var.service != "" ? [var.service] : []

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
      destination_vault_arn = module.cross_region_vault["this"].backup_vault_arn
      lifecycle = {
        delete_after = schedule.retention
      }
    }
  }]
}
