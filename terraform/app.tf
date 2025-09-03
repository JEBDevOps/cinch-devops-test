# IAM Role and Instance Profile for the App Instance
resource "aws_iam_role" "app" {
  name = "${var.project_name}-app-role"
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
    Name = "${var.project_name}-app-role"
  }
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "app_s3_access" {
  name = "AppS3Access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.logs.arn
      },
      {
        Sid      = "ObjectRW"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.logs.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app.name
}

# App Security Group
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow HTTP from VPC and SSH from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

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
    Name = "${var.project_name}-app-sg"
  }
}

# Data source for App AMI
data "aws_ssm_parameter" "app_ami" {
  name = var.app_instance_ami_id
}

# App EC2 Instance
resource "aws_instance" "app" {
  instance_type          = var.app_instance_type
  ami                    = data.aws_ssm_parameter.app_ami.value
  iam_instance_profile   = aws_iam_instance_profile.app.name
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    yum update -y

    # Install Docker on Amazon Linux 2
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose
    yum install -y python3-pip
    pip3 install docker-compose

    # Create a directory for the monitoring stack
    mkdir -p /home/ec2-user/monitoring
    cd /home/ec2-user/monitoring

    # Create docker-compose.yml
    cat <<'EOF' > docker-compose.yml
version: '3.7'
services:
  app:
    image: nginxdemos/hello
    ports:
      - "5000:80"
    restart: unless-stopped

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:0.10.0
    command: -nginx.scrape-uri http://app/stub_status
    restart: unless-stopped
    labels:
      - "prometheus.scrape=true"
      - "prometheus.port=9113"

  grafana-agent:
    image: grafana/agent:v0.20.0
    volumes:
      - ./agent.yaml:/etc/agent/agent.yaml
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
EOF

    # Create agent.yaml
    cat <<'EOF' > agent.yaml
metrics:
  wal_directory: /tmp/grafana-agent-wal
  global:
    scrape_interval: 15s
    remote_write:
      - url: ${var.grafana_prometheus_endpoint}
        basic_auth:
          username: ${var.grafana_prometheus_user_id}
          password: ${var.grafana_api_key}
  configs:
    - name: docker-scrape
      scrape_configs:
        - job_name: 'docker'
          docker_sd_configs:
            - host: unix:///var/run/docker.sock
          relabel_configs:
            - source_labels: [__meta_docker_container_label_prometheus_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_docker_container_label_prometheus_port, __meta_docker_network_ip]
              action: replace
              target_label: __address__
              regex: (.+);(.+)
              replacement: $2:$1
EOF

    # Start the stack
    docker-compose up -d

    # AWS CLI + S3 smoke test
    yum install -y awscli
    hostname > /tmp/boot.txt
    date >> /tmp/boot.txt
    aws s3 cp /tmp/boot.txt s3://${aws_s3_bucket.logs.id}/app/boot-app.txt || true

    # Optional quick check
    curl -s http://localhost:5000 || true
  EOT

  tags = {
    Name = "${var.project_name}-app"
  }
}
