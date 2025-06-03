output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "ID of the security group for the bastion host"
  value       = aws_security_group.bastion.id
}

output "private_key" {
  description = "Private key for SSH access to the bastion host"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "key_name" {
  description = "Name of the key pair used for the bastion host"
  value       = aws_key_pair.this.key_name
} 