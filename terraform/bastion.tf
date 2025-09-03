locals {
  my_public_ip = chomp(data.http.my_public_ip.response_body)
}

data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from a specific CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_public_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# EIP for Bastion Host
resource "aws_eip" "bastion" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-bastion-eip"
  }
}

# Data source for Amazon Linux 2 AMI
data "aws_ssm_parameter" "bastion_ami" {
  name = var.bastion_instance_ami_id
}

# Bastion Host Instance
resource "aws_instance" "bastion" {
  instance_type          = var.bastion_instance_type
  ami                    = data.aws_ssm_parameter.bastion_ami.value
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# Associate EIP with Bastion instance
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
