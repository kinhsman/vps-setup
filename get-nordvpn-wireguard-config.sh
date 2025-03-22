#!/bin/bash

# Script to generate WireGuard config for NordVPN

# Prompt user for NordVPN API token
read -p "Enter your NordVPN API token: " TOKEN

# Get private key
PRIVATE_KEY=$(curl -s -u token:${TOKEN} https://api.nordvpn.com/v1/users/services/credentials | jq -r .nordlynx_private_key)

# Get server recommendation data
SERVER_DATA=$(curl -s "https://api.nordvpn.com/v1/servers/recommendations?&filters\[servers_technologies\]\[identifier\]=wireguard_udp&limit=1")

# Extract PUBLIC_KEY and ENDPOINT with specific jq queries
PUBLIC_KEY=$(echo "$SERVER_DATA" | jq -r '.[0].technologies[] | select(.identifier=="wireguard_udp") | .metadata[] | select(.name=="public_key") | .value')
ENDPOINT=$(echo "$SERVER_DATA" | jq -r '.[0].hostname')

# Create config file
CONFIG_FILE="nordvpn-wg.conf"

cat > $CONFIG_FILE << EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.5.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${ENDPOINT}:51820
EOL

echo "WireGuard configuration has been generated in $CONFIG_FILE"
echo "Contents of $CONFIG_FILE:"
cat $CONFIG_FILE
