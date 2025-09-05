#!/bin/bash
# Simple, portable logging. All output will be redirected to this file.
exec > /var/log/user-data-app.log 2>&1

set -euxo pipefail

echo "--- Starting user_data_app.sh script ---"

echo "Updating yum packages..."
dnf update -y

echo "Installing the latest Docker Engine from Docker's official repository..."

# Install dnf-plugins-core, which provides the repo-add command
dnf -y install dnf-plugins-core

# Add the official Docker repo for CentOS
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Adjust release server version in the path as it will not match with Amazon Linux 2023
sed -i 's/$releasever/9/g' /etc/yum.repos.d/docker-ce.repo

# Install Docker Engine
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Enabling and starting docker service..."
systemctl enable docker
systemctl start docker

echo "Adding ec2-user to docker group..."
usermod -aG docker ec2-user

echo "Creating monitoring directory..."
mkdir -p /home/ec2-user/monitoring

echo "Creating docker-compose.yml..."
cat <<'EOF' > /home/ec2-user/monitoring/docker-compose.yml
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

  grafana-alloy:
    image: grafana/alloy:latest
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: run /etc/alloy/config.alloy
    restart: unless-stopped
EOF

echo "Creating config.alloy..."
cat <<EOF > /home/ec2-user/monitoring/config.alloy
prometheus.remote_write "default" {
  endpoint {
    url = "${grafana_prometheus_endpoint}"
    basic_auth {
      username = "${grafana_prometheus_user_id}"
      password = "${grafana_api_key}"
    }
  }
}

discovery.docker "docker_containers" {
  host = "unix:///var/run/docker.sock"
}

prometheus.scrape "docker_scrape" {
  targets = discovery.docker.docker_containers.targets
  forward_to = [prometheus.remote_write.default.receiver]

  relabel_config {
    source_labels = ["__meta_docker_container_label_prometheus_scrape"]
    action        = "keep"
    regex         = "true"
  }
  relabel_config {
    source_labels = ["__meta_docker_container_label_prometheus_port", "__meta_docker_network_ip"]
    action        = "replace"
    target_label  = "__address__"
    regex         = "(.+);(.+)"
    replacement   = "\$2:\$1"
  }
}
EOF

echo "Changing ownership of monitoring directory..."
chown -R ec2-user:ec2-user /home/ec2-user/monitoring

echo "Running docker compose as ec2-user..."
sudo -u ec2-user bash -c "cd /home/ec2-user/monitoring && docker compose up -d"

echo "Installing awscli..."
yum install -y awscli

echo "Running S3 smoke test..."
hostname > /tmp/boot.txt
date >> /tmp/boot.txt
aws s3 cp /tmp/boot.txt s3://${s3_bucket_id}/app/boot-app.txt || true

echo "Running curl smoke test..."
curl -s http://localhost:5000 || true

echo "--- Finished user_data_app.sh script ---"
