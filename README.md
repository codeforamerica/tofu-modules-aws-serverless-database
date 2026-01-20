# AWS Serverless Database Module

[![Main Checks][badge-checks]][code-checks] [![GitHub Release][badge-release]][latest-release]

This module launches an [Aurora Serverless v2][aurora-serverless] database
cluster. Aurora serverless clusters measure capacity in [ACUs] (Aurora Capacity
Units); each unit is approximately 2 GB of memory with corresponding CPU and
networking.

## Usage

Add this module to your `main.tf` (or appropriate) file and configure the inputs
to match your desired configuration. For example:

```hcl
module "database" {
  source = "github.com/codeforamerica/tofu-modules-aws-serverless-database?ref=1.4.0"

  project     = "my-project"
  environment = "dev"
  service     = "web"

  logging_key_arn = module.logging.kms_key_arn
  secrets_key_arn = module.secrets.kms_key_arn
  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.private_subnets
  ingress_cidrs   = module.vpc.private_subnets_cidr_blocks

  min_capacity = 2
  max_capacity = 32
}
```

Make sure you re-run `tofu init` after adding the module to your configuration.

```bash
tofu init
tofu plan
```

To update the source for this module, pass `-upgrade` to `tofu init`:

```bash
tofu init -upgrade
```

### Role name limitations

When creating the database cluster, a role will be created for database
monitoring. A random string will be appended to the role name to ensure it is
unique and allow replacement without a conflict. However, this means the rest
of the role name must be **38 characters or fewer**.

The role name is constructed as follows (before the suffix is added):

```hcl
role_name = "${project}-${environment}-[${service}-]-db-mon"
```

If this combined string is longer than 38 characters, the module will fail to
create the database cluster. You can help to reduce the length of the role by
specifying short names for your project and (optionally) service using the
`project_short` and `service_short` input variables, respectively.

## Inputs

| Name                        | Description                                                                                                                                | Type           | Default        | Required |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------------- | -------------- | -------- |
| logging_key_arn             | ARN of the KMS key for logging.                                                                                                            | `string`       | n/a            | yes      |
| ingress_cidrs               | List of CIDR blocks to allow ingress. This is typically your private subnets.                                                              | `list(string)` | n/a            | yes      |
| project                     | Name of the project.                                                                                                                       | `string`       | n/a            | yes      |
| secrets_key_arn             | ARN of the KMS key for secrets. This will be used to encrypt database credentials.                                                         | `string`       | n/a            | yes      |
| subnets                     | List of subnet ids the database instances may be placed in.                                                                                | `list(string)` | n/a            | yes      |
| vpc_id                      | Id of the VPC to launch the database cluster into.                                                                                         | `string`       | n/a            | yes      |
| apply_immediately           | Whether to apply changes immediately rather than during the next maintenance window. WARNING: This may result in a restart of the cluster! | `bool`         | `false`        | no       |
| backup_retention_period     | Number of days to retain automatic backups, between 1 and 35.                                                                              | `number`       | `31`           | no       |
| [cluster_parameters]        | Parameters to be set on the database cluster.                                                                                              | `list(object)` | `[]`           | no       |
| enable_data_api             | Whether to enable the [Data API][data-api] for the database cluster.                                                                       | `bool`         | `false`        | no       |
| engine                      | Database engine to use for the cluster. Valid values are 'mysql' and 'postgresql'.                                                         | `string`       | `"postgresql"` | no       |
| engine_version              | Version of the database engine to use. If left empty, the latest version will be used. Changing this value will result in downtime.        | `string`       | `null`         | no       |
| environment                 | Environment for the project.                                                                                                               | `string`       | `"dev"`        | no       |
| force_delete                | Force deletion of resources. If changing to true, be sure to apply before destroying.                                                      | `bool`         | `false`        | no       |
| iam_authentication          | Whether to enable IAM authentication for the database cluster.                                                                             | `bool`         | `true`         | no       |
| instances                   | Number of instances to create in the database cluster.                                                                                     | `number`       | `2`            | no       |
| key_recovery_period         | Recovery period for deleted KMS keys in days. Must be between 7 and 30.                                                                    | `number`       | `30`           | no       |
| min_capacity                | Minimum capacity for the serverless cluster in ACUs.                                                                                       | `number`       | `2`            | no       |
| max_capacity                | Maximum capacity for the serverless cluster in ACUs.                                                                                       | `number`       | `10`           | no       |
| password_rotation_frequency | Number of days between automatic password rotations for the root user Set to `0` to disable automatic rotation.                            | `number`       | `30`           | no       |
| project_short               | Short name for the project. Used in resource names with character limits. Defaults to project.                                             | `string`       | `var.project`  | no       |
| service                     | Optional service that these resources are supporting. Example: 'api', 'web', 'worker'                                                      | `string`       | `""`           | no       |
| service_short               | Short name for the service. Used in resource names with character limits. Defaults to service.                                             | `string`       | `var.service`  | no       |
| [security_group_rules]      | Security group rules to control cluster ingress and egress.                                                                                | `map(object)`  | `{}`           | no       |
| skip_final_snapshot         | Whether to skip the final snapshot when destroying the database cluster.                                                                   | `bool`         | `false`        | no       |
| snapshot_identifier         | Optional name or ARN of the snapshot to restore the cluster from. Only applicable on create.                                               | `bool`         | `false`        | no       |
| tags                        | Optional tags to be applied to all resources.                                                                                              | `map(string)`  | `{}`           | no       |

### cluster_parameters

You can override the default cluster parameters by passing a list of parameters
and their values. Some parameters can be applied immediately, while others will
require a restart of the cluster. See the documentation for the appropriate
database engine to determine which parameters can be applied immediately.

> [!NOTE]
> If a parameter requires a restart, you _must_ set the `apply_method` to
> `"pending-reboot"`.

```hcl
cluster_parameters = [
  {
    name  = "log_statement"
    value = "all"
  },
  {
    name = "shared_preload_libraries"
    value = "pg_stat_statements,pglogical"
    apply_method = "pending-reboot"
  }
]
```

| Name         | Description                                                         | Type     | Default       | Required |
| ------------ | ------------------------------------------------------------------- | -------- | ------------- | -------- |
| name         | Name of the parameter to set.                                       | `string` | n/a           | yes      |
| value        | Value to set the parameter to.                                      | `string` | n/a           | yes      |
| apply_method | How to apply the parameter. Can be `immediate` or `pending-reboot`. | `string` | `"immediate"` | no       |

### security_group_rules

Security group rules control network access to the cluster. By default, the
cluster will not be available on the network can only be accessed via the
[Data API][data-api]. You can use `security_group_rules` to define rules to
ingress and/or egress traffic.

> [!TIP]
> If you just want to allow access to the database from one or more CIDR blocks,
> you can use the `ingress_cidrs` input variable for convenience.

```hcl
security_group_rules = {
  vpc_peer = {
    description = "Allow access from VPC peer"
    type        = "ingress"
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = ["10.123.0.0/16"]
  }
  replication = {
    description = "Allow egress for replication"
    type        = "egress"
    cidr_blocks = ["10.123.0.0/16"]
  }
}
```

> [!CAUTION]
> Be careful when using `egress` rules. In most cases, this will not be
> necessary and can present a security risk. If you do need to use `egress`
> rules, be sure to restrict the narrowest set of destinations that are
> necessary.
>
> Leaving your egress rules too broad can allow your data to be exfiltrated by
> a bad actor.

| Name                     | Description                                                               | Type           | Default                 | Required |
| ------------------------ | ------------------------------------------------------------------------- | -------------- | ----------------------- | -------- |
| description              | Description of the rule.                                                  | `string`       | `"Managed by OpenTofu"` | no       |
| type                     | Type of rule. Can be `ingress` or `egress`.                               | `string`       | `"ingress"`             | no       |
| protocol                 | Protocol to use. Valid values: `icmp`, `icmpv6`, `tcp`, `udp`, or `all`.  | `string`       | `"tcp"`                 | no       |
| from_port                | Starting port for the rule. Defaults to the port for the database engine. | `number`       | `5432` or `3306`        | no       |
| to_port                  | Ending port for the rule. Defaults to the port for the database engine.   | `number`       | `5432` or `3306`        | no       |
| cidr_blocks              | List of CIDR blocks to allow access.                                      | `list(string)` | `[]`                    | no       |
| ipv6_cidr_blocks         | List of IPv6 CIDR blocks to allow access.                                 | `list(string)` | `[]`                    | no       |
| prefix_list_ids          | List of prefix list IDs to allow access.                                  | `list(string)` | `[]`                    | no       |
| source_security_group_id | ID of another security group to allow access.                             | `string`       | `null`                  | no       |

## Outputs

| Name                | Description                                      | Type     |
| ------------------- | ------------------------------------------------ | -------- |
| cluster_endpoint    | DNS endpoint to connect to the database cluster. | `string` |
| cluster_id          | ID of the RDS database cluster.                  | `string` |
| cluster_resource_id | Resource ID of the RDS database cluster.         | `string` |
| secret_arn          | ARN of the secret holding database credentials.  | `string` |

[acus]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.how-it-works.html#aurora-serverless-v2.how-it-works.capacity
[aurora-serverless]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html
[badge-checks]: https://github.com/codeforamerica/tofu-modules-aws-serverless-database/actions/workflows/main.yaml/badge.svg
[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-aws-serverless-database?logo=github&label=Latest%20Release
[code-checks]: https://github.com/codeforamerica/tofu-modules-aws-serverless-database/actions/workflows/main.yaml
[cluster_parameters]: #cluster_parameters
[data-api]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/data-api.html
[latest-release]: https://github.com/codeforamerica/tofu-modules-aws-serverless-database/releases/latest
[security_group_rules]: #security_group_rules
