# File: templates/client.tpl
# --------------------------
[Interface]
PrivateKey = ${private_key} # Private key for this client
Address = ${address}
DNS = 8.8.8.8

[Peer]
PublicKey = ${server_pub_key} # Public key for the server
Endpoint = ${server_ip}:51820
AllowedIPs = ${join(", ", allowed_ips)}
PersistentKeepalive = 25
