resource "aws_iam_policy" "iam_db_user" {
  for_each = var.iam_db_users

  name        = join("-", [local.prefix, "db", each.key])
  description = "Allows IAM authentication to the ${local.prefix} Aurora cluster as \"${each.key}\"."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/iam-user-policy.yaml.tftpl", {
    account : data.aws_caller_identity.identity.account_id,
    cluster_id : module.database.cluster_resource_id
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
    region      = data.aws_region.current.name
    engine      = var.engine
    databases   = join(",", each.value.databases)
    privileges  = each.value.privileges
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/iam-user-create.sh.tftpl", {
      username      = each.key
      cluster_arn   = module.database.cluster_arn
      secret_arn    = module.database.cluster_master_user_secret[0].secret_arn
      region        = data.aws_region.current.name
      engine        = var.engine
      databases_csv = join(",", each.value.databases)
      privileges    = each.value.privileges
    })
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy
    command = templatefile("${path.module}/templates/iam-user-destroy.sh.tftpl", {
      username      = self.triggers.username
      cluster_arn   = self.triggers.cluster_arn
      secret_arn    = self.triggers.secret_arn
      region        = self.triggers.region
      engine        = self.triggers.engine
      databases_csv = self.triggers.databases
    })
    interpreter = ["bash", "-c"]
  }
}
