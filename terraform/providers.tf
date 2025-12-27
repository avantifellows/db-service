terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Backend for remote state (create bucket/table first; see backend-bootstrap)
  backend "s3" {
    bucket         = "111766607077-dbservice-test-terraform-state"
    key            = "dbservice/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "111766607077-dbservice-test-terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}


