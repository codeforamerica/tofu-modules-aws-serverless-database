terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      version = ">= 6.61"
      source  = "hashicorp/aws"
    }
    null = {
      version = ">= 3.0"
      source  = "hashicorp/null"
    }
  }
}
