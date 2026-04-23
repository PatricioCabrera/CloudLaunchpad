output "vpc_id" {
  description = "ID of the AWS main VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Subnet IDs within the VPC"
  value       = { for subnet, value in aws_subnet.this : subnet => value.id }
}

output "subnet_cidrs" {
  description = "Subnet CIDRs within the VPC"
  value       = { for subnet, value in aws_subnet.this : subnet => value.cidr_block }
}
