# DNS for avantifellows.org is authoritative on Cloudflare (not Route53), so the
# record must be created via the Cloudflare provider. A CNAME to the shared ALB's
# stable DNS name survives ALB IP rotation.
resource "cloudflare_record" "this" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_prefix
  type    = "CNAME"
  value   = data.aws_lb.shared.dns_name
  proxied = var.dns_proxied
  ttl     = 1 # 1 = "auto"; required when proxied, harmless when not
}
