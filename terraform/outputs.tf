output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.address
}

output "database_url" {
  description = "Complete database URL (with password visible)"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:${var.db_port}/${var.db_name}"
  sensitive   = true
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.cloudflare_subdomain}.${var.cloudflare_domain}"
}

output "cloudflare_record_status" {
  description = "Cloudflare proxy status"
  value       = length(cloudflare_record.app) > 0 ? (cloudflare_record.app[0].proxied ? "Proxied (Orange Cloud)" : "DNS Only (Grey Cloud)") : "No Cloudflare record created"
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}


