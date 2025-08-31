data "cloudflare_zone" "main" {
  count = var.cloudflare_domain != "" ? 1 : 0
  name  = var.cloudflare_domain
}

resource "cloudflare_record" "app" {
  count   = length(data.cloudflare_zone.main) > 0 && var.cloudflare_subdomain != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main[0].id
  name    = var.cloudflare_subdomain
  content = aws_lb.main.dns_name
  type    = "CNAME"
  proxied = var.cloudflare_proxied
  ttl     = var.cloudflare_proxied ? 1 : 300
  comment = "Managed by Terraform - ${var.environment} environment"
}


