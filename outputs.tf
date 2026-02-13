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

output "secret_arn" {
  description = "ARN of the secret containing the user credentials."
  value       = module.database.cluster_master_user_secret[0].secret_arn
}
