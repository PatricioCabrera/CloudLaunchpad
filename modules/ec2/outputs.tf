output "security_group_id" {
  description = "ID of the app instance security group"
  value       = aws_security_group.app.id
}

output "instance_id" {
  description = "Instance ID — the target for `aws ssm start-session --target <id>`"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IP the app answers on, once uvicorn is running"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "Where to expect /health"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}
