resource "aws_cloudfront_distribution" "backend_cdn" {
  origin {
    domain_name = aws_lb.lb.dns_name
    origin_id   = aws_lb.lb.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  aliases = [data.dotenv.env_file.env["CLOUDFLARE_CNAME"]]

  default_cache_behavior {
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = aws_lb.lb.dns_name
    compress                 = true
    viewer_protocol_policy   = "allow-all"
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${local.environment_prefix}backend-cdn"
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:111766607077:certificate/5477789a-3421-407f-b8ce-df2ce8949e48"
    ssl_support_method  = "sni-only"
  }

  price_class = "PriceClass_200"
}

resource "null_resource" "cloudfront_invalidation" {
  triggers = {
    distribution_id = aws_cloudfront_distribution.backend_cdn.id
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.backend_cdn.id} --paths /*"
  }

  depends_on = [aws_cloudfront_distribution.backend_cdn]
}
