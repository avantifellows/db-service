# Security group for the Application Load Balancer
resource "aws_security_group" "sg_for_elb" {
  name        = "${local.environment_prefix}sg-for-elb" # Environment-specific name
  description = "security group for ELB"
  vpc_id      = aws_vpc.main.id # Associates with VPC

  ingress {
    description      = "Allow HTTP from anywhere" # Port 80 ingress
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Allow from any IPv4
    ipv6_cidr_blocks = ["::/0"]      # Allow from any IPv6
  }

  ingress {
    description      = "Allow HTTPS from anywhere" # Port 443 ingress
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Allow all traffic to anywhere" # Allow all outbound
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for EC2 instances in the ASG
resource "aws_security_group" "sg_for_ec2" {
  name        = "${local.environment_prefix}sg-for-ec2"
  description = "security group for EC2"
  vpc_id      = aws_vpc.main.id
  depends_on = [
    aws_security_group.sg_for_elb
  ] # Ensures ELB security group exists first

  ingress {
    description     = "Allow http from load balancer" # Allow HTTP only from ALB
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_for_elb.id]
  }

  egress {
    description = "Allow all traffic to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "sg_bastion" {
  name        = "${local.environment_prefix}sg-bastion"
  description = "Bastion host security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere" # Allow SSH access from internet
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Rule to allow SSH from Bastion to EC2 instances
resource "aws_security_group_rule" "allow_ssh_from_bastion_to_ec2" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${aws_instance.bastion_host.private_ip}/32"] # Use the private IP of the bastion host
  security_group_id = aws_security_group.sg_for_ec2.id
  depends_on        = [aws_security_group.sg_for_ec2]
}
