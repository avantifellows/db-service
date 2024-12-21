locals {
  environment = terraform.workspace
  environment_prefix = "${local.environment}-DB-"
  
  env_config = var.environments[local.environment]
  
  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = "DB-Service"
  }

  pem_file_path = data.dotenv.env_file.env["PEM_FILE_PATH"]
}

data "dotenv" "env_file" {
  filename = local.environment == "staging" ? ".env.staging" : ".env.production"
}