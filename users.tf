resource "aws_iam_policy" "iam_db_user" {
  for_each = var.iam_db_users

  name        = join("-", [local.prefix, "db", each.key])
  description = "Allows IAM authentication to the ${local.prefix} Aurora cluster as \"${each.key}\"."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/iam-user-policy.yaml.tftpl", {
    account : data.aws_caller_identity.identity.account_id,
    cluster_id : module.database.cluster_resource_id
    partition : data.aws_partition.current.partition,
    region : data.aws_region.current.region,
    username : each.key,
  })))

  tags = var.tags
}

resource "null_resource" "iam_db_user" {
  for_each   = var.iam_db_users
  depends_on = [module.database]

  triggers = {
    username    = each.key
    cluster_arn = module.database.cluster_arn
    secret_arn  = module.database.cluster_master_user_secret[0].secret_arn
    region      = data.aws_region.current.region
    engine      = var.engine
    databases   = join(",", each.value.databases)
    privileges  = each.value.privileges
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/iam-user-create.sh.tftpl", {
      username      = each.key
      cluster_arn   = module.database.cluster_arn
      secret_arn    = module.database.cluster_master_user_secret[0].secret_arn
      region        = data.aws_region.current.region
      engine        = var.engine
      databases_csv = join(",", each.value.databases)
      privileges    = each.value.privileges
    })
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy
    command = templatefile("${path.module}/templates/iam-user-destroy.sh.tftpl", {
      username    = self.triggers.username
      cluster_arn = self.triggers.cluster_arn
      secret_arn  = self.triggers.secret_arn
      region      = self.triggers.region
      engine      = self.triggers.engine
    })
    interpreter = ["bash", "-c"]
  }
}

# Generates a random password via the AWS Secrets Manager API. Ephemeral
# resources are not persisted to state, so the password is only held in
# memory during the apply and never written to the state file.
ephemeral "aws_secretsmanager_random_password" "db_user" {
  for_each = var.db_users

  password_length = 32
  # Exclude characters that would break SQL string literals or bash expansion.
  exclude_characters = "'\"\\/`@"
}

resource "aws_secretsmanager_secret" "db_user" {
  for_each = var.db_users

  kms_key_id = var.secrets_key_arn
  name = join("/", compact([
    var.project,
    var.environment,
    var.service,
    "database",
    "user",
    each.key,
  ]))

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_user" {
  for_each = var.db_users

  secret_id = aws_secretsmanager_secret.db_user[each.key].id

  secret_string_wo = jsonencode({
    username = each.key
    password = ephemeral.aws_secretsmanager_random_password.db_user[each.key].random_password
    host     = module.database.cluster_endpoint
    engine   = var.engine
  })
  secret_string_wo_version = 1

  lifecycle {
    # Ignore changes to this secret, we only want to set the initial values.
    ignore_changes = [secret_string_wo_version]
  }
}

resource "null_resource" "db_user" {
  for_each   = var.db_users
  depends_on = [module.database, aws_secretsmanager_secret_version.db_user]

  triggers = {
    username        = each.key
    cluster_arn     = module.database.cluster_arn
    secret_arn      = module.database.cluster_master_user_secret[0].secret_arn
    user_secret_arn = aws_secretsmanager_secret.db_user[each.key].arn
    region          = data.aws_region.current.region
    engine          = var.engine
    databases       = join(",", each.value.databases)
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/db-user-create.sh.tftpl", {
      username        = self.triggers.username
      cluster_arn     = self.triggers.cluster_arn
      secret_arn      = self.triggers.secret_arn
      user_secret_arn = self.triggers.user_secret_arn
      region          = self.triggers.region
      engine          = self.triggers.engine
      databases_csv   = self.triggers.databases
    })
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy
    command = templatefile("${path.module}/templates/db-user-destroy.sh.tftpl", {
      username    = self.triggers.username
      cluster_arn = self.triggers.cluster_arn
      secret_arn  = self.triggers.secret_arn
      region      = self.triggers.region
      engine      = self.triggers.engine
    })
    interpreter = ["bash", "-c"]
  }
}
