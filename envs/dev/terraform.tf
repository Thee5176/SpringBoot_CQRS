terraform {
  cloud {
    organization = "Thee5176"
    workspaces {
      name = "AWS_for_Accounting_Project"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9.0"
    }
  }

  required_version = ">= 1.13.0"
}