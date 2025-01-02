# Creates an Application Load Balancer (ALB)
resource "aws_lb" "lb" {
  name               = "${local.environment_prefix}lb-asg"               # Environment-specific ALB name
  internal           = false                                             # External/Internet-facing load balancer
  load_balancer_type = "application"                                     # ALB type (Layer 7)
  security_groups    = [aws_security_group.sg_for_elb.id]                # Security group for the ALB
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_1a.id] # Public subnets for the ALB
  depends_on         = [aws_internet_gateway.gw]                         # Ensures internet gateway exists first
  tags = {
    Name = "${local.environment_prefix}lb"
  }
}

# Creates a target group for the ALB
resource "aws_lb_target_group" "alb_tg" {
  name     = "${local.environment_prefix}lb-alb-tg" # Environment-specific target group name
  port     = 80                                     # Port for HTTP traffic
  protocol = "HTTP"                                 # Protocol for communication
  vpc_id   = aws_vpc.main.id                        # VPC where targets will be registered
  health_check {
    path = "/" # Health check endpoint
  }
}

# Creates an HTTP listener for the ALB
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.lb.arn # Associates listener with ALB
  port              = "80"          # Listen on HTTP port
  protocol          = "HTTP"        # HTTP protocol

  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn # Forward traffic to target group
    type             = "forward"
  }
}

# Creates an HTTPS listener for the ALB
resource "aws_lb_listener" "alb_https_listener" {
  load_balancer_arn = aws_lb.lb.arn                                                                          # Associates listener with ALB
  port              = "443"                                                                                  # Listen on HTTPS port
  protocol          = "HTTPS"                                                                                # HTTPS protocol
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"                                                  # Modern TLS security policy
  certificate_arn   = "arn:aws:acm:ap-south-1:111766607077:certificate/9a8f45c3-e386-4ef7-bf4b-659180eb638f" # SSL certificate

  default_action {
    type             = "forward" # Forward traffic to target group
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}