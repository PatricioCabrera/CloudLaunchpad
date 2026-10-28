# The ec2 module is behind count, so every output here is a list of zero or one.
# one() collapses that: the single element when enable_ec2 is true, null when it
# is false. Indexing [0] would fail the plan outright whenever the toggle is off.

output "app_instance_id" {
  description = "Target for `aws ssm start-session --target <id>` — null when enable_ec2 is false"
  value       = one(module.ec2[*].instance_id)
}

output "app_url" {
  description = "Where to expect /health — null when enable_ec2 is false"
  value       = one(module.ec2[*].app_url)
}
