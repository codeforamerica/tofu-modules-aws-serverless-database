output "cluster_endpoint" {
  description = "Endpoint of the RDS database endpoint to connect to."
  value       = module.database.cluster_endpoint
}

output "secret_arn" {
  description = "ARN of the secret containing the user credentials."
  value       = module.database.cluster_master_user_secret[0].secret_arn
}
