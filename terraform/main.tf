locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Default VPC and Subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Availability zones (for reference / spreading)
data "aws_availability_zones" "available" {
  state = "available"
}


