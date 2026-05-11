resource "aws_route53_record" "this" {
  zone_id = var.route53_zone_id
  name    = "${var.domain_prefix}.avantifellows.org"
  type    = "A"

  alias {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}
