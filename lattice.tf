# Shares the cluster with other accounts through VPC Lattice. An ARN-type
# resource configuration points at the cluster, and RAM shares that
# configuration with the listed principals.
resource "aws_vpclattice_resource_configuration" "this" {
  for_each = local.lattice_share

  name                        = local.lattice_name
  type                        = "ARN"
  resource_gateway_identifier = each.value.resource_gateway_id

  resource_configuration_definition {
    arn_resource {
      arn = module.database.cluster_arn
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = length(local.lattice_name) <= 40 && can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", local.lattice_name))
      error_message = "The VPC Lattice resource configuration name \"${local.lattice_name}\" must be at most 40 characters of lowercase letters, digits and single hyphens. Adjust project_short, service_short or environment."
    }
  }
}

resource "aws_ram_resource_share" "lattice" {
  for_each = local.lattice_share

  name                      = "${local.prefix}-lattice"
  allow_external_principals = each.value.allow_external_principals

  tags = local.tags
}

resource "aws_ram_resource_association" "lattice" {
  for_each   = local.lattice_share
  depends_on = [aws_security_group_rule.this]

  resource_arn       = aws_vpclattice_resource_configuration.this["this"].arn
  resource_share_arn = aws_ram_resource_share.lattice["this"].arn
}

resource "aws_ram_principal_association" "lattice" {
  for_each = local.lattice_principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.lattice["this"].arn
}
