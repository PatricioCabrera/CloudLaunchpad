# Block 2 scaffold — public_ip to be added once the instance exists.

output "security_group_id" {
  description = "ID of the app instance security group"
  value       = aws_security_group.app.id
}
