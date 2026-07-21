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
  # Authenticates with a scoped API token (Zone → DNS → Edit on avantifellows.org)
  # instead of the account-wide legacy Global API Key, so the blast radius is
  # limited to the DNS records this config manages. Sensitive — supply via
  # TF_VAR_cloudflare_api_token at apply time; not needed by the deploy workflow.
  api_token = var.cloudflare_api_token
}
