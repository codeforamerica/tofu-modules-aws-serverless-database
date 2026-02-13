resource "aws_kms_key" "database" {
  description             = "Database encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    region : data.aws_region.current.name,
  })))

  tags = var.tags
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.project}/${var.environment}/${var.service != "" ? "${var.service}/" : ""}database"
  target_key_id = aws_kms_key.database.id
}

resource "aws_kms_key" "backups" {
  for_each = var.configure_aws_backup ? toset(["this"]) : toset([])

  description             = "Encryption key for backups of ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  multi_region            = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/backup-key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    region : data.aws_region.current.name,
  })))

  tags = var.tags
}

resource "aws_kms_alias" "backups" {
  for_each = var.configure_aws_backup ? toset(["this"]) : toset([])

  name          = "alias/${var.project}/${var.environment}/${var.service != "" ? "${var.service}/" : ""}backups"
  target_key_id = aws_kms_key.backups["this"].id
}
