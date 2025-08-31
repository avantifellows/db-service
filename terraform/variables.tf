#############################
# Core settings
#############################
variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

#############################
# EC2 / App settings
#############################
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
}

variable "app_port" {
  description = "Port for Phoenix application"
  type        = number
}

#############################
# RDS settings
#############################
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
}

variable "backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "dbservice"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

#############################
# Domain / SSL
#############################
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for SSL"
  type        = string
}

#############################
# Application config
#############################
variable "git_repo_url" {
  description = "Git repository URL for application code"
  type        = string
}

variable "git_branch" {
  description = "Git branch to deploy"
  type        = string
}

# Note: database_url is constructed from RDS instance, not passed as variable

variable "secret_key_base" {
  description = "Phoenix secret key base"
  type        = string
  sensitive   = true
}

variable "bearer_token" {
  description = "API bearer token for authentication"
  type        = string
  sensitive   = true
}

variable "whitelisted_domains" {
  description = "Comma-separated list of whitelisted domains"
  type        = string
}

variable "google_credentials_json" {
  description = "Base64-encoded Google service account JSON"
  type        = string
  sensitive   = true
}

variable "pool_size" {
  description = "Database connection pool size"
  type        = number
  default     = 20
}

#############################
# Cloudflare
#############################
variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
  default     = ""
}

variable "cloudflare_api_key" {
  description = "Cloudflare Global API Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_domain" {
  description = "Base domain managed in Cloudflare"
  type        = string
  default     = ""
}

variable "cloudflare_subdomain" {
  description = "Subdomain for this environment"
  type        = string
  default     = ""
}

variable "cloudflare_proxied" {
  description = "Whether to proxy traffic through Cloudflare"
  type        = bool
  default     = false
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID (optional - leave empty to auto-lookup by domain)"
  type        = string
  default     = ""
}

variable "cloudflare_enable_healthcheck" {
  description = "Create Cloudflare HTTP(S) healthcheck for the app"
  type        = bool
  default     = true
}

#############################
# Optional performance tuning
#############################
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = true
}

variable "alb_health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/health"
}


