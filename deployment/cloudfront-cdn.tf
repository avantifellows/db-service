# Creates a CloudFront distribution to serve content from the load balancer
resource "aws_cloudfront_distribution" "backend_cdn" {
  # Configures the origin (source) for the CDN
  origin {
    domain_name = aws_lb.lb.dns_name # Uses the load balancer's DNS name as the origin
    origin_id   = aws_lb.lb.dns_name # Unique identifier for this origin

    # Configures how CloudFront connects to the origin
    custom_origin_config {
      http_port              = 80          # Port for HTTP traffic
      https_port             = 443         # Port for HTTPS traffic
      origin_protocol_policy = "http-only" # Only use HTTP to connect to the origin
      origin_ssl_protocols   = ["TLSv1.2"] # Allowed SSL/TLS protocols
    }
  }

  enabled         = true # Enables the CloudFront distribution
  is_ipv6_enabled = true # Enables IPv6 support

  aliases = [data.dotenv.env_file.env["CLOUDFLARE_CNAME"]] # Custom domain name for the distribution

  # Defines how the CDN handles requests and caching
  default_cache_behavior {
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"] # HTTP methods allowed
    cached_methods           = ["GET", "HEAD"]                                              # Methods that can be cached
    target_origin_id         = aws_lb.lb.dns_name                                           # Links to the origin defined above
    compress                 = true                                                         # Enables compression
    viewer_protocol_policy   = "allow-all"                                                  # Allows both HTTP and HTTPS
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"                       # Policy for caching behavior
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"                       # Policy for origin requests
  }

  # Configures geographic restrictions
  restrictions {
    geo_restriction {
      locations        = []     # No location restrictions
      restriction_type = "none" # Allows access from all locations
    }
  }

  # Adds tags for resource management
  tags = {
    Name = "${local.environment_prefix}backend-cdn" # Tags the distribution with environment-specific name
  }

  # Configures SSL/TLS settings
  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:111766607077:certificate/5477789a-3421-407f-b8ce-df2ce8949e48" # SSL certificate
    ssl_support_method  = "sni-only"                                                                            # Uses Server Name Indication (SNI)
  }

  price_class = "PriceClass_200" # Sets price class to use all edges except South America and Australia
}

# Creates a resource to invalidate CloudFront cache when changes occur
resource "null_resource" "cloudfront_invalidation" {
  triggers = {
    distribution_id = aws_cloudfront_distribution.backend_cdn.id # Triggers on distribution ID changes
  }

  # Runs AWS CLI command to invalidate the cache with specified AWS profile
  provisioner "local-exec" {
    command = local.is_windows ? "set \"AWS_DEFAULT_PROFILE=${trimspace(data.dotenv.env_file.env["LOCAL_AWS_PROFILE_NAME"])}\" && aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.backend_cdn.id} --paths /*" : "export AWS_DEFAULT_PROFILE='${trimspace(data.dotenv.env_file.env["LOCAL_AWS_PROFILE_NAME"])}' && aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.backend_cdn.id} --paths /*"
  }

  depends_on = [aws_cloudfront_distribution.backend_cdn] # Ensures distribution exists before invalidation
}
