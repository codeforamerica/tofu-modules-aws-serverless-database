# Managed here instead of by rds-aurora, so we're not tied to whatever
# rule resource that module uses internally.
resource "aws_security_group_rule" "this" {
  for_each = local.security_group_rules

  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = module.database.security_group_id

  # AWS only allows one destination type per rule - an empty list on the
  # others still counts as "set" and conflicts with source_security_group_id.
  description              = each.value.description
  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  ipv6_cidr_blocks         = length(each.value.ipv6_cidr_blocks) > 0 ? each.value.ipv6_cidr_blocks : null
  prefix_list_ids          = length(each.value.prefix_list_ids) > 0 ? each.value.prefix_list_ids : null
  source_security_group_id = each.value.source_security_group_id
}

resource "aws_security_group_rule" "replica" {
  for_each = var.replica.enabled ? local.replica_security_group_rules : {}

  region            = var.replica.region
  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = module.database_replica["this"].security_group_id

  description              = each.value.description
  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  ipv6_cidr_blocks         = length(each.value.ipv6_cidr_blocks) > 0 ? each.value.ipv6_cidr_blocks : null
  prefix_list_ids          = length(each.value.prefix_list_ids) > 0 ? each.value.prefix_list_ids : null
  source_security_group_id = each.value.source_security_group_id
}

# These already exist inside the module for current consumers, same
# resource type - move them instead of recreating.
moved {
  from = module.database.aws_security_group_rule.this
  to   = aws_security_group_rule.this
}
