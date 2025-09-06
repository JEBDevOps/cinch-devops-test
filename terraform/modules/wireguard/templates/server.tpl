#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

apt-get update && apt-get install -y wireguard iptables
mkdir -p /etc/wireguard

# --- detect egress interface ---
IFACE="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = ${server_private_key}
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o __IFACE__ -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o __IFACE__ -j MASQUERADE

${peer_blocks}
EOF

# Replace placeholder with the actual interface name
sed -i "s/__IFACE__/$IFACE/g" /etc/wireguard/wg0.conf

sysctl -w net.ipv4.ip_forward=1
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

mkdir -p /home/ssm-user/wireguard

######################################################
# Create a script to add peers
######################################################

cat <<'EOF' > /home/ssm-user/wireguard/add-peer.sh
#!/bin/bash

# Usage: ./add-peer.sh <peer-name>
set -e

PEER_NAME=$1
WG_DIR=/home/ssm-user/wireguard
WG_CONF=/etc/wireguard/wg0.conf
VPN_SUBNET="10.8.0"
SERVER=${wg_server}
#SERVER_PUBLIC_KEY=$(cat $WG_DIR/server_public.key)
SERVER_PUBLIC_KEY=${server_public_key}

if [ -z "$PEER_NAME" ]; then
  echo "Usage: $0 <peer-name>"
  exit 1
fi

# Find the next available IP
USED_IPS=$(grep AllowedIPs $WG_CONF | cut -d' ' -f3 | cut -d'/' -f1 | cut -d'.' -f4)
NEXT_ID=2
while echo "$USED_IPS" | grep -q "$NEXT_ID"; do
  ((NEXT_ID++))
done
PEER_IP="$VPN_SUBNET.$NEXT_ID"

# Generate keys
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo $PRIVATE_KEY | wg pubkey)

# Save keys to disk
echo "$PRIVATE_KEY" > "$WG_DIR/$${PEER_NAME}_private.key"
echo "$PUBLIC_KEY" > "$WG_DIR/$${PEER_NAME}_public.key"

# Append peer to server config
echo -e "\n[Peer]" | sudo tee -a $WG_CONF
echo "PublicKey = $PUBLIC_KEY" | sudo tee -a $WG_CONF
echo "AllowedIPs = $PEER_IP/32" | sudo tee -a $WG_CONF

# Create client config
cat > "$WG_DIR/$${PEER_NAME}.conf" <<CONFIG
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $PEER_IP/24
DNS = ${vpc_dns_resolver}

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER:51820
AllowedIPs = ${vpc_cidr}
PersistentKeepalive = 25
CONFIG

echo "Peer $PEER_NAME added with IP $PEER_IP"
echo "Client config: $WG_DIR/$${PEER_NAME}.conf"

# Optional: restart WireGuard to apply
read -p "Restart WireGuard now? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
  sudo wg-quick down wg0
  sudo wg-quick up wg0
fi

EOF

sudo chmod +x /home/ssm-user/wireguard/add-peer.sh

sudo apt install -y fish
