module "backup_vault" {
  source  = "cloudposse/backup/aws"
  version = ">= 1.1.1"

  providers = {
    aws = aws.backup
  }

  namespace  = var.backup_namespace
  stage      = var.environment
  name       = local.prefix
  attributes = ["database_backup_vault"]

  tags = {
    Attributes  = "rds-dr"
    Namespace   = var.backup_namespace
  }

  vault_enabled    = true
  iam_role_enabled = true
  plan_enabled     = false
}

module "backup" {
  source  = "cloudposse/backup/aws"
  version = ">= 1.1.1"

  namespace  = var.backup_namespace
  stage      = var.environment
  name       = local.prefix
  attributes = ["database_back"]

  plan_name_suffix = "aws-backup-daily"
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

  rules = [
    {
      name              = "${local.prefix}-daily"
      schedule          = "cron(0 18 ? * * *)"
      start_window      = 320
      completion_window = 1440

      lifecycle = {
        delete_after = 31
      }

      copy_action = {
        destination_vault_arn = module.backup_vault.backup_vault_arn
        lifecycle = {
          delete_after = 31
        }
      }
    },
    {
      name              = "${local.prefix}-monthly"
      schedule          = "cron(0 18 1 * ? *)"
      start_window      = 320
      completion_window = 1440

      lifecycle = {
        delete_after = 395
      }

      copy_action = {
        destination_vault_arn = module.backup_vault.backup_vault_arn
        lifecycle = {
          delete_after = 395
        }
      }
    },
    {
      name              = "${local.prefix}-yearly"
      schedule          = "cron(0 18 1 1 ? *)"
      start_window      = 320
      completion_window = 1440

      lifecycle = {
        delete_after = 1095
      }

      copy_action = {
        destination_vault_arn = module.backup_vault.backup_vault_arn
        lifecycle = {
          delete_after = 1095
        }
      }
    }
  ]
}
