output "aws_instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "aws_instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "aws_instance_private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "aws_security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.ec2.id
}