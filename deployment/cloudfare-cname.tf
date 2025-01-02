# Creates a DNS record in Cloudflare
resource "cloudflare_record" "cdn_cname" {
  zone_id = data.dotenv.env_file.env["CLOUDFLARE_ZONE_ID"]      # The Cloudflare Zone ID from .env file
  name    = data.dotenv.env_file.env["CLOUDFLARE_CNAME"]        # The CNAME record name/subdomain from .env file
  value   = aws_cloudfront_distribution.backend_cdn.domain_name # Points to the CloudFront distribution domain
  type    = "CNAME"                                             # Specifies this is a CNAME record type
  proxied = false                                               # Disables Cloudflare proxying/CDN for this record
}
