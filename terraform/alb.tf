resource "aws_lb_target_group" "this" {
  # name_prefix (not name) so create_before_destroy below actually works — a
  # fixed name collides with the still-existing old TG when a change forces
  # replacement (e.g. a port change). AWS caps target-group name_prefix at 6
  # chars; the Environment tag distinguishes staging/prod.
  name_prefix = "dbsvc-"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Pin LiveView clients to the same task for the WebSocket upgrade. Without
  # this, the ALB might land the GET on task A but the WS on task B and the
  # session breaks.
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  deregistration_delay = var.stop_timeout

  # Target group can't be replaced while still attached to a listener; let
  # TF create the new one before destroying the old one during in-place edits.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.alb_https_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = ["${var.domain_prefix}.avantifellows.org"]
    }
  }
}
