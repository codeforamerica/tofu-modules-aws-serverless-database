output "backup_key_arn" {
  description = "ARN of the KMS key for backups, if created."
  value       = var.configure_aws_backup ? aws_kms_key.backups["this"].arn : null
}

output "backup_vault_arn" {
  description = "ARN of the backup vault, if created."
  value       = var.configure_aws_backup ? module.backup["this"].backup_vault_arn : null
}

output "backup_vault_replica_arn" {
  description = "ARN of the backup vault replica, if created."
  value       = var.configure_aws_backup && var.backup_replica_region != null ? aws_backup_vault.cross_region_vault["this"].arn : null
}

output "cluster_arn" {
  description = "ARN of the RDS database cluster."
  value       = module.database.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint of the RDS database endpoint to connect to."
  value       = module.database.cluster_endpoint
}

output "cluster_id" {
  description = "ID of the RDS database cluster."
  value       = module.database.cluster_id
}

output "cluster_resource_id" {
  description = "Resource ID of the RDS database cluster."
  value       = module.database.cluster_resource_id
}

output "db_user_secret_arns" {
  description = <<-EOT
    Map of database username to the ARN of the Secrets Manager secret
    containing their credentials.
    EOT
  value       = { for username, secret in aws_secretsmanager_secret.db_user : username => secret.arn }
}

output "global_cluster_id" {
  description = "ID of the Aurora Global Database, if created."
  value       = var.replica.enabled ? aws_rds_global_cluster.this["this"].id : null
}

output "iam_db_user_policy_arns" {
  description = <<-EOT
      Map of IAM database username to the ARN of the IAM policy granting
      `rds-db:connect` access for that user.
    EOT
  value       = { for username, policy in aws_iam_policy.iam_db_user : username => policy.arn }
}

output "lattice_share" {
  description = <<-EOT
    ARNs of the VPC Lattice share, if `lattice_share` is set. Contains
    `configuration_arn` (the resource configuration) and `share_arn` (the RAM
    resource share).
    EOT
  value = var.lattice_share != null ? {
    configuration_arn = aws_vpclattice_resource_configuration.this["this"].arn
    share_arn         = aws_ram_resource_share.lattice["this"].arn
  } : null
}

output "reader_endpoint" {
  description = "Reader endpoint of the database cluster."
  value       = module.database.cluster_reader_endpoint
}

output "replica_cluster_endpoint" {
  description = "Endpoint of the replica cluster, if created."
  value       = var.replica.enabled ? module.database_replica["this"].cluster_endpoint : null
}

output "secret_arn" {
  description = "ARN of the secret containing the user credentials."
  value       = module.database.cluster_master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "ID of the security group attached to the database cluster."
  value       = module.database.security_group_id
}
