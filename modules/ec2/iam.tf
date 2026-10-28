# The role trusts EC2 to assume it
resource "aws_iam_role" "app" {
  name = "cloudlaunchpad-app-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "Service" = "ec2.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
}

# Grants SSM calls
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The instance profile that goes attached to the ec2 instance
resource "aws_iam_instance_profile" "app" {
  name = "cloudlaunchpad-app-iam-instance-profile"
  role = aws_iam_role.app.name
}
