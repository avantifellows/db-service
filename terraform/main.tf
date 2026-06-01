terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "db-service"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "cloudflare" {
  # Authenticates with a legacy Global API Key (account-wide) rather than a
  # scoped API token. email is the key owner; api_key is the sensitive value,
  # supplied via TF_VAR_cloudflare_api_key at apply time.
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}
