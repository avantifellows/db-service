# Outputs the DNS name of the Application Load Balancer
output "load_balancer_dns" {
  description = "The DNS name of the load balancer" # Description of the output
  value       = aws_lb.lb.dns_name                  # ALB's DNS name for accessing the application
}

# Outputs the public IP of the Bastion host for SSH access
output "bastion_host_public_ip" {
  description = "The public IP address of the Bastion host" # Description of the output
  value       = aws_instance.bastion_host.public_ip         # Public IP for SSH access to Bastion
}
