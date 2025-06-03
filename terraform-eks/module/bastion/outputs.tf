output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "ID of the security group for the bastion host"
  value       = aws_security_group.bastion.id
}

output "instance_id" {
  description = "ID of the bastion instance for Session Manager connection"
  value       = aws_instance.bastion.id
} 