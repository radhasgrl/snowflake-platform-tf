terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally local state — this is a one-time, human-applied stack.
  # It must never be run by the pipeline's own (narrowly-scoped) IAM identity.
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
}
