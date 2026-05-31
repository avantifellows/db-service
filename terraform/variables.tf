################################################################################
# Required per environment
################################################################################

variable "environment" {
  description = "Environment slug used as a suffix for env-specific resources (\"staging\" or \"prod\")."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be \"staging\" or \"prod\"."
  }
}

variable "domain_prefix" {
  description = "Subdomain prefix for the service (e.g. \"staging-db\" → staging-db.avantifellows.org)."
  type        = string
}

################################################################################
# Required per environment — sensitive (set via TF_VAR_* env vars in CI)
################################################################################

variable "database_url" {
  description = "Ecto DATABASE_URL for the Repo connection."
  type        = string
  sensitive   = true
}

variable "secret_key_base" {
  description = "Phoenix SECRET_KEY_BASE."
  type        = string
  sensitive   = true
}

variable "bearer_token" {
  description = "API bearer token enforced by AuthenticationMiddleware."
  type        = string
  sensitive   = true
}

variable "google_credentials_json" {
  description = "Raw JSON content of the Google service account used by Goth."
  type        = string
  sensitive   = true
}

variable "whitelisted_domains" {
  description = "Comma-separated host list enforced by DomainWhitelistPlug."
  type        = string
}

variable "dashboard_user" {
  description = "Username for the LiveDashboard / admin import basic auth. Required (no default — see Phase 0 #8)."
  type        = string
  sensitive   = true
}

variable "dashboard_pass" {
  description = "Password for the LiveDashboard / admin import basic auth. Required (no default — see Phase 0 #8)."
  type        = string
  sensitive   = true
}

################################################################################
# Tunables (sensible defaults)
################################################################################

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "app_port" {
  description = "Port the container listens on. Must be 8080 — the shared ALB's security group only permits egress to targets on 8080."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units (0.5 vCPU = 512)."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Baseline number of tasks. Auto-scaling governs the actual count."
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Auto-scaling minimum task count."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Auto-scaling maximum task count."
  type        = number
  default     = 3
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization (%) for auto-scaling."
  type        = number
  default     = 70
}

variable "scale_in_cooldown" {
  description = "Seconds to wait after a scale-in before considering another (long: protects WebSocket sessions and Oban jobs)."
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Seconds to wait after a scale-out before considering another."
  type        = number
  default     = 60
}

variable "stop_timeout" {
  description = "Seconds ECS waits after SIGTERM before force-killing. Matches Oban shutdown_grace_period."
  type        = number
  default     = 120
}

variable "pool_size" {
  description = "Ecto connection pool size."
  type        = string
  default     = "10"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the container log group."
  type        = number
  default     = 30
}

variable "image_tag" {
  description = "ECR image tag the ECS service should run. CI overrides this each deploy; \"latest\" is fine for the first apply since the service is created with desiredCount that will be replaced by the deploy pipeline."
  type        = string
  default     = "latest"
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule that routes the configured host to this service."
  type        = number
  # Per-env defaults set in envs/*.tfvars to avoid collisions with existing rules on the shared ALB.
}

################################################################################
# Existing AWS infrastructure references
################################################################################

variable "vpc_id" {
  description = "Existing AF VPC."
  type        = string
  default     = "vpc-0a48a661"
}

variable "subnet_ids" {
  description = "Subnets to place Fargate tasks in."
  type        = list(string)
  default     = ["subnet-84ffe8ec", "subnet-434c080f", "subnet-5cd65827"]
}

variable "alb_name" {
  description = "Existing shared ALB to attach a listener rule to."
  type        = string
  default     = "af-load-balancer"
}

variable "alb_https_listener_arn" {
  description = "ARN of the HTTPS:443 listener on the shared ALB."
  type        = string
  default     = "arn:aws:elasticloadbalancing:ap-south-1:111766607077:listener/app/af-load-balancer/8c412f577b269ab0/5b6cfc3f4677e5c4"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for avantifellows.org (zone overview in the Cloudflare dashboard)."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS:Edit on the avantifellows.org zone. Set via TF_VAR_cloudflare_api_token at apply time; not needed by the deploy workflow."
  type        = string
  sensitive   = true
}

variable "dns_proxied" {
  description = "Cloudflare proxy (orange cloud). true requires SSL/TLS mode Full (strict); false (DNS-only/grey) connects clients straight to the ALB. Set per env in envs/*.tfvars."
  type        = bool
  default     = false
}

################################################################################
# Bootstrap toggles
################################################################################

variable "create_ci_user" {
  description = "Whether to create the shared db-service-ci-deploy IAM user. Set to true on exactly one environment's apply (it's a single shared user)."
  type        = bool
  default     = false
}
