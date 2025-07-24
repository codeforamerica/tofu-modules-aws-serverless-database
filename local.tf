locals {
  prefix        = "${var.project}-${var.environment}${var.service != "" ? "-${var.service}" : ""}"
  port          = var.engine == "postgresql" ? 5432 : 3306
  project_short = var.project_short != "" ? var.project_short : var.project
  service_short = var.service_short != "" ? var.service_short : var.service
  short_prefix  = "${local.project_short}-${var.environment}${var.service != "" ? "-${local.service_short}" : ""}"

  # Merge any ingress CIDR blocks with the security group rules.
  security_group_rules = merge(
    length(var.ingress_cidrs) == 0 ? {} : {
      ingress_cidrs = {
        description = "Allow ingress from specified CIDR blocks."
        type        = "ingress"
        protocol    = "tcp"
        from_port   = local.port
        to_port     = local.port
        cidr_blocks = var.ingress_cidrs
      }
    },
    {
      for key, rule in var.security_group_rules : key => {
        description              = rule.description
        type                     = rule.type
        protocol                 = rule.protocol
        from_port                = rule.from_port == null ? local.port : rule.from_port
        to_port                  = rule.to_port == null ? local.port : rule.to_port
        cidr_blocks              = rule.cidr_blocks
        ipv6_cidr_blocks         = rule.ipv6_cidr_blocks
        prefix_list_ids          = rule.prefix_list_ids
        source_security_group_id = rule.source_security_group_id
      }
    }
  )
}
