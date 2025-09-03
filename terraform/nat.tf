# Security Group
resource "aws_security_group" "nat" {
  count = var.create_nat_instance ? 1 : 0

  name        = "${var.project_name}-nat-sg"
  description = "Allow SSH in (from VPC) and NAT forwarding"
  vpc_id      = aws_vpc.main.id


  # Allow SSH from within the VPC (mirrors CFN tcp/22 from VpcCidr)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }


  # Allow any from private subnet (mirrors CFN -1 protocol from PrivateSubnetCidr)
  ingress {
    description = "All from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "${var.project_name}-nat-sg"
  }
}

# EIP for NAT Instance
resource "aws_eip" "nat" {
  count = var.create_nat_instance ? 1 : 0

  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# IAM Role and Instance Profile for NAT Instance
resource "aws_iam_role" "nat" {
  count = var.create_nat_instance ? 1 : 0

  name = "${var.project_name}-nat-role"
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
    Name = "${var.project_name}-nat-role"
  }
}

# Attach SSM Managed Instance Core policy to NAT instance
resource "aws_iam_role_policy_attachment" "nat_ssm" {
  count = var.create_nat_instance ? 1 : 0

  role       = aws_iam_role.nat[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach IAM Instance Profile to NAT instance
resource "aws_iam_instance_profile" "nat" {
  count = var.create_nat_instance ? 1 : 0

  name = "${var.project_name}-nat-profile"
  role = aws_iam_role.nat[0].name
}

# Data source for latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# NAT Instance
resource "aws_instance" "nat" {
  count = var.create_nat_instance ? 1 : 0

  instance_type          = var.default_instance_type
  ami                    = data.aws_ssm_parameter.latest_ami.value
  iam_instance_profile   = aws_iam_instance_profile.nat[0].name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.nat[0].id]
  key_name               = var.key_name == "NONE" ? null : var.key_name
  source_dest_check      = false

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    # --- settings ---
    VPC_CIDR=${var.vpc_cidr}

    # --- enable IPv4 forwarding now and persist ---
    sysctl -w net.ipv4.ip_forward=1
    if ! grep -q '^net.ipv4.ip_forward *= *1' /etc/sysctl.conf; then
      echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi

    # --- detect egress interface (usually eth0/ens5) ---
    IFACE="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

    # --- install and enable iptables-services (AL2/CentOS7) ---
    (dnf -y install iptables-services || yum -y install iptables-services)
    systemctl enable --now iptables

    # --- flush old rules to avoid duplicates on reruns ---
    iptables -t nat -F
    iptables -F

    # --- NAT and forward rules ---
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -s "$VPC_CIDR" -j ACCEPT

    # --- persist rules for reboot ---
    iptables-save > /etc/sysconfig/iptables
  EOT

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# Associate EIP with NAT instance
resource "aws_eip_association" "nat" {
  count = var.create_nat_instance ? 1 : 0

  instance_id   = aws_instance.nat[0].id
  allocation_id = aws_eip.nat[0].id
}

# Default route for the private subnet via the NAT instance
resource "aws_route" "private_default_via_nat" {
  count = var.create_nat_instance ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}