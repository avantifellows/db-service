output "load_balancer_dns" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.lb.dns_name
}

output "bastion_host_public_ip" {
  description = "The public IP address of the Bastion host"
  value       = aws_instance.bastion_host.public_ip
}