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

# Amazon Linux 2023, resolved from the public SSM parameter. A hardcoded ami-*
# is wrong in two directions: the ID differs per region, and it pins the image
# to whatever Amazon published the day it was copied in.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "app" {
  # The data source marks every parameter value sensitive, SecureString or not.
  # Left alone it redacts the AMI in the plan, which is the one thing worth
  # reading there.
  ami           = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]

  # No key pair. Session Manager reaches the shell through this profile, so
  # there is no port 22 open and no private key on disk or in state.
  iam_instance_profile = aws_iam_instance_profile.app.name

  # The subnet sets map_public_ip_on_launch already; stating it here keeps the
  # module honest if it is ever pointed at a different one.
  associate_public_ip_address = true

  # user_data runs once, on first boot. Editing the file changes nothing on a
  # running instance — this flag makes Terraform replace the instance instead
  # of updating an attribute nothing will ever read again.
  user_data                   = file("${path.module}/cloud-init/app.yaml")
  user_data_replace_on_change = true

  # IMDSv2 only. v1 answers any process that can reach 169.254.169.254 with no
  # proof it belongs on the instance, which turns an SSRF in the app into the
  # instance profile's credentials.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "cloudlaunchpad-app"
  }
}
