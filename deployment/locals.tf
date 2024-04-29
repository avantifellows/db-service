locals {
  environment_prefix = terraform.workspace == "default" ? "staging-DB-" : "${terraform.workspace}-DB-"
}

data "dotenv" "env_file" {
  filename = (
    terraform.workspace == "default" || terraform.workspace == "staging"
  ) ? ".env.staging" : ".env.production"
}