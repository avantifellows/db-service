# Specifies required providers and their versions
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Official AWS provider
      version = "~> 5.0"        # Uses 5.x version
    }

    dotenv = {
      source  = "jrhouston/dotenv" # Provider for loading .env files
      version = "~> 1.0"           # Uses 1.x version
    }

    cloudflare = {
      source  = "cloudflare/cloudflare" # Official Cloudflare provider
      version = "~> 5"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region                   = "ap-south-1"                                       # Mumbai region
  shared_config_files      = [data.dotenv.env_file.env["AWS_CONFIG_FILE"]]      # AWS config file path
  shared_credentials_files = [data.dotenv.env_file.env["AWS_CREDENTIALS_FILE"]] # AWS credentials file path
}

# Configures dotenv provider for loading environment variables
provider "dotenv" {}

# Configures Cloudflare provider with authentication
provider "cloudflare" {
  email   = data.dotenv.env_file.env["CLOUDFLARE_EMAIL"]
  api_key = data.dotenv.env_file.env["CLOUDFLARE_API_KEY"]
}
