resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/aws/ec2/nginx/access"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/aws/ec2/nginx/error"
  retention_in_days = 14
}


