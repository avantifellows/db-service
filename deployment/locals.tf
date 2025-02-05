# Defines local variables used throughout the configuration
locals {
  environment        = terraform.workspace        # Gets current workspace name (staging/production)
  environment_prefix = "${local.environment}-DB-" # Creates prefix for resource naming

  env_config = var.environmentSpecificConfig[local.environment] # Loads environment-specific configurations

  # Defines common tags applied to resources
  common_tags = {
    Environment = local.environment # Current environment
    ManagedBy   = "Terraform"       # Infrastructure management tool
    Project     = "DB-Service"      # Project name
  }

  # Path to SSH key file from environment variables
  pem_file_path = data.dotenv.env_file.env["PEM_FILE_PATH"]
}

# Loads environment-specific variables from .env files
data "dotenv" "env_file" {
  filename = local.environment == "staging" ? ".env.staging" : ".env.production"
}
