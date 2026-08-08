# Block 2 scaffold — pending:
#   - aws_instance with #cloud-config user_data (uvicorn systemd unit)
#   - user_data_replace_on_change = true

resource "aws_security_group" "app" {
  name        = "cloudlaunchpad-app-sg"
  description = "App instance: inbound on the app port from the operator IP only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "cloudlaunchpad-app"
  }
}

# Rules are standalone resources, never inline ingress/egress blocks. Inline
# blocks assume they own the group's entire rule set and delete anything they
# did not create, so the two styles cannot coexist on one group.
resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "uvicorn, operator IP only"

  cidr_ipv4   = var.allowed_cidr
  ip_protocol = "tcp"
  from_port   = var.app_port
  to_port     = var.app_port
}

# Open egress is load-bearing, not an oversight: cloud-init clones the repo from
# GitHub and installs from PyPI on first boot. Restrict this and the instance
# boots clean, serves nothing, and the only evidence is cloud-init-output.log.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound — cloud-init needs GitHub and PyPI"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
