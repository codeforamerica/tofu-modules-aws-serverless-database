resource "aws_iam_policy" "iam_user" {
  for_each = var.iam_users

  name        = "${local.prefix}-db-${each.key}"
  description = "Allows IAM authentication to the ${local.prefix} Aurora cluster as '${each.key}'."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.identity.account_id}:dbuser:${module.database.cluster_resource_id}/${each.key}"
    }]
  })

  tags = var.tags
}

resource "null_resource" "iam_user" {
  for_each = var.iam_users

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
    command = templatefile("${path.module}/templates/iam_user_create.sh.tftpl", {
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
    when    = destroy
    command = templatefile("${path.module}/templates/iam_user_destroy.sh.tftpl", {
      username    = self.triggers.username
      cluster_arn = self.triggers.cluster_arn
      secret_arn  = self.triggers.secret_arn
      region      = self.triggers.region
      engine      = self.triggers.engine
    })
    interpreter = ["bash", "-c"]
  }

  depends_on = [module.database]
}
