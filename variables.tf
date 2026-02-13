variable "apply_immediately" {
  type        = bool
  description = "Whether to apply changes immediately rather than during the next maintenance window."
  default     = false
}

variable "automatic_backup_retention_period" {
  type        = number
  description = "Number of days to retain automatic backups, between 1 and 35."
  default     = 31

  validation {
    condition     = var.automatic_backup_retention_period > 0 && var.automatic_backup_retention_period < 36
    error_message = "Automatic backup retention must be between 1 and 35 days."
  }
}

variable "backup_namespace" {
  type        = string
  description = "Namespace for database backups"
  default     = "cfa"

}

variable "backup_replica_region" {
  type        = string
  description = <<-EOT
    Region to use for cross-region backup replication. If not specified, no
    replica will be created. If specified, the module will create a backup vault
    in the specified region and configure the backup schedules to replicate to
    the replica vault.
    EOT
  default     = null
}

variable "backup_retention_period" {
  type        = number
  description = "Deprecated: Use `automatic_backup_retention_period` instead."
  default     = null
  deprecated  = "Use automatic_backup_retention_period instead."

  validation {
    condition     = var.backup_retention_period == null || (var.backup_retention_period > 0 && var.backup_retention_period < 36)
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "backup_schedules" {
  type = list(object({
    name              = string
    schedule          = string
    start_window      = optional(number, 320)
    completion_window = optional(number, 1440)
    retention         = number
  }))
  description = "Backup schedules to create for the database cluster."
  default = [{
    name              = "daily"
    schedule          = "cron(0 9 ? * * *)"
    start_window      = 320
    completion_window = 1440
    retention         = 31
    }, {
    name              = "monthly"
    schedule          = "cron(0 9 1 * ? *)"
    start_window      = 320
    completion_window = 1440
    retention         = 395
    }, {
    name              = "yearly"
    schedule          = "cron(0 9 1 1 ? *)"
    start_window      = 320
    completion_window = 1440
    retention         = 1095
  }]
}

variable "cluster_parameters" {
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  description = "Parameters to be set on the database cluster."
  default     = []
}

variable "configure_aws_backup" {
  type        = bool
  description = <<-EOT
    Whether to configure AWS Backup with the defined backup schedules.
    EOT
  default     = false
}

variable "enable_data_api" {
  type        = bool
  description = "Whether to enable the Data API for the database cluster."
  default     = false
}

variable "engine" {
  type        = string
  description = "Database engine to use for the cluster. Valid values are 'mysql' and 'postgresql'."
  default     = "postgresql"

  validation {
    condition     = contains(["mysql", "postgresql"], var.engine)
    error_message = "Valid enginers are 'mysql' and 'postgresql'."
  }
}

variable "engine_version" {
  type        = string
  description = "Version of the database engine to use. If left empty, the latest version will be used. Changing this value will result in downtime."
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "dev"
}

variable "force_delete" {
  type        = bool
  description = "Force deletion of resources. If changing to true, be sure to apply before destroying."
  default     = false
}

variable "logging_key_arn" {
  type        = string
  description = "ARN of the KMS key for logging."
}

variable "iam_authentication" {
  type        = bool
  description = "Whether to enable IAM authentication for the database cluster."
  default     = true
}

variable "ingress_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks to allow ingress. This is typically your private subnets."
}

variable "instances" {
  type        = number
  description = "Number of instances to create in the database cluster."
  default     = 2
}
variable "key_recovery_period" {
  type        = number
  default     = 30
  description = "Recovery period for deleted KMS keys in days. Must be between 7 and 30."

  validation {
    condition     = var.key_recovery_period > 6 && var.key_recovery_period < 31
    error_message = "Recovery period must be between 7 and 30."
  }
}

variable "min_capacity" {
  type        = number
  description = "Minimum capacity for the serverless cluster in ACUs."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum capacity for the serverless cluster in ACUs."
  default     = 10
}

variable "password_rotation_frequency" {
  type        = number
  description = "Number of days between automatic password rotations for the root user. Set to 0 to disable automatic rotation."
  default     = 30
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "project_short" {
  type        = string
  description = "Short name for the project. Used in resource names with character limits. Defaults to project."
  default     = ""
}

variable "secrets_key_arn" {
  type        = string
  description = "ARN of the KMS key for secrets. This will be used to encrypt database credentials."
}

variable "security_group_rules" {
  type = map(object({
    description              = optional(string, "Managed by OpenTofu")
    type                     = optional(string, "ingress")
    protocol                 = optional(string, "tcp")
    from_port                = optional(number)
    to_port                  = optional(number)
    cidr_blocks              = optional(list(string), [])
    ipv6_cidr_blocks         = optional(list(string), [])
    prefix_list_ids          = optional(list(string), [])
    source_security_group_id = optional(string, null)
  }))
  description = "Security group rules to control cluster ingress and egress."
  default     = {}
}

variable "service" {
  type        = string
  description = "Optional service that these resources are supporting. Example: 'api', 'web', 'worker'"
  default     = ""
}

variable "service_short" {
  type        = string
  description = "Short name for the service. Used in resource names with character limits. Defaults to service."
  default     = ""
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot when destroying the database cluster."
  default     = false
}

variable "snapshot_identifier" {
  type        = string
  description = "Optional name or ARN of the snapshot to restore the cluster from. Only applicable on create."
  default     = ""
}

variable "subnets" {
  type        = list(string)
  description = "List of subnet ids the database instances may be placed in"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "Id of the VPC to launch the database cluster into."
}
