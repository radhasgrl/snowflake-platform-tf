terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally local — this config bootstraps the remote backend
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
}
