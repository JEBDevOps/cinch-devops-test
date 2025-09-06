locals {
  vpc_dns_resolver = cidrhost(var.vpc_cidr, 2)
}

resource "aws_iam_role" "ssm_instance_role" {
  name = "${var.env}-wg-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.env}-wg-ssm-profile"
  role = aws_iam_role.ssm_instance_role.name
}



resource "aws_security_group" "wireguard" {
  name        = "wireguard-sg-${var.env}"
  description = "Allow WireGuard"
  vpc_id      = var.vpc

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1024
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "wireguard_asymmetric_key" "wireguard_key" {
}

resource "wireguard_asymmetric_key" "client_keys" {
  count = length(var.clients)
}

locals {
  peer_blocks = [
    for i, client in var.clients :
    <<-EOT
    [Peer] # ${client.name}
    PublicKey = ${wireguard_asymmetric_key.client_keys[i].public_key}
    AllowedIPs = ${client.address}
    EOT
  ]
}

resource "aws_instance" "wireguard" {
  ami                  = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_ids[0]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  source_dest_check    = false

  vpc_security_group_ids = [aws_security_group.wireguard.id]

  user_data = templatefile("${path.module}/templates/server.tpl", {
    server_private_key = wireguard_asymmetric_key.wireguard_key.private_key
    server_public_key  = wireguard_asymmetric_key.wireguard_key.public_key
    vpc_cidr           = var.vpc_cidr
    wg_server          = aws_eip.wireguard.public_ip
    vpc_dns_resolver   = local.vpc_dns_resolver
    peer_blocks        = join("\n", local.peer_blocks)
  })

  tags = {
    Name = "wireguard-server"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "wireguard" {
  tags = {
    Name = "wireguard-${var.env}"
  }
}

resource "aws_eip_association" "wireguard" {
  instance_id   = aws_instance.wireguard.id
  allocation_id = aws_eip.wireguard.id
}
