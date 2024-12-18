terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    dotenv = {
      source  = "jrhouston/dotenv"
      version = "~> 1.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region                   = "ap-south-1"
  shared_config_files      = ["C:/Users/amanb/.aws/config"]
  shared_credentials_files = ["C:/Users/amanb/.aws/credentials"]
}

provider "dotenv" {}

provider "cloudflare" {
  email   = data.dotenv.env_file.env["CLOUDFLARE_EMAIL"]
  api_key = data.dotenv.env_file.env["CLOUDFLARE_API_KEY"]
}
