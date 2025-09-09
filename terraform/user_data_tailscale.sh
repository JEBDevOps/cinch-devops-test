#!/bin/bash
set -euxo pipefail
exec > /var/log/user-data.log 2>&1

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Run Tailscale
tailscale up \
  --authkey=${tailscale_auth_key} \
  --advertise-routes=${private_subnet_cidr} \
  --hostname=tf-subnet-router
