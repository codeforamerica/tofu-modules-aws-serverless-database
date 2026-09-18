data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_region" "replica" {
  count    = var.replica_region != null ? 1 : 0
  provider = aws.replica
}

data "aws_rds_engine_version" "this" {
  engine  = "aurora-${var.engine}"
  version = var.engine_version
  latest  = true
}
