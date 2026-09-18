terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      version               = ">= 5.44"
      source                = "hashicorp/aws"
      configuration_aliases = [aws.replica]
    }
    null = {
      version = ">= 3.0"
      source  = "hashicorp/null"
    }
  }
}
