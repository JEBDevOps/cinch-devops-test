resource "aws_security_group" "tailscale" {
  count = var.enable_tailscale ? 1 : 0

  name        = "${var.project_name}-tailscale-sg"
  description = "Allow Tailscale traffic"
  vpc_id      = aws_vpc.main.id

  # Allow inbound Tailscale traffic (UDP 41641)
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH from bastion for management
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-tailscale-sg"
  }
}

resource "aws_iam_role" "tailscale" {
  count = var.enable_tailscale ? 1 : 0

  name = "${var.project_name}-tailscale-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-tailscale-role"
  }
}

resource "aws_iam_role_policy_attachment" "tailscale_ssm" {
  count = var.enable_tailscale ? 1 : 0

  role       = aws_iam_role.tailscale[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "tailscale" {
  count = var.enable_tailscale ? 1 : 0

  name = "${var.project_name}-tailscale-profile"
  role = aws_iam_role.tailscale[0].name
}

data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "tailscale_router" {
  count = var.enable_tailscale ? 1 : 0

  ami                    = data.aws_ami.ubuntu_jammy.id
  instance_type          = var.default_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.tailscale[0].id]
  iam_instance_profile   = aws_iam_instance_profile.tailscale[0].name
  source_dest_check      = false

  user_data = templatefile("${path.module}/user_data_tailscale.sh", {
    tailscale_auth_key  = var.tailscale_auth_key
    private_subnet_cidr = var.private_subnet_cidr
  })

  tags = {
    Name = "${var.project_name}-tailscale-router"
  }
}
