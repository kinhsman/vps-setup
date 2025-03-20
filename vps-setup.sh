#!/bin/bash

set -e  # Exit on error

# Update and upgrade system packages
echo "Updating system packages..."
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install required dependencies
echo "Installing required dependencies..."
apt install -y curl

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

# Ensure Docker is running
systemctl is-active --quiet docker || systemctl start docker

# Ensure Docker Compose (plugin) is installed
if ! docker compose version &> /dev/null; then
    echo "Docker Compose (plugin) is missing. Installing..."
    apt install -y docker-compose-plugin
else
    echo "Docker Compose (plugin) is already installed."
fi

# Prompt user for input
read -p "Enter the public domain name or IP of the VPS: " WG_HOST
echo "Enter your Cloudflare API Token (input will be hidden):"
read -s -p "Token: " CLOUDFLARE_API_TOKEN
echo -e "\n"  # Ensure newline after silent input

# Debugging (remove this after verifying inputs)
echo "DEBUG: WG_HOST=${WG_HOST}, CLOUDFLARE_API_TOKEN=******"

# Create necessary directory for Docker Compose
mkdir -p /opt/wg-easy/wg-data
chmod 700 /opt/wg-easy/wg-data
cd /opt/wg-easy || exit

# Create docker-compose.yml file
cat <<EOF > docker-compose.yml
services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy
    restart: always
    environment:
      - LANG=en
      - WG_HOST=${WG_HOST}
      - PASSWORD_HASH='\$2a\$12\$o7iDxKq3rQHPhJ/JuqUZDu0pakCKhR4GBzsBxt/qO5yCkXWY2U1k2'
      - PORT=51821
      - WG_PORT=65222
      - WG_DEFAULT_DNS=10.1.30.12, sangnetworks.com
    volumes:
      - /opt/wg-easy/wg-data:/etc/wireguard
    ports:
      - "65222:65222/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
 
  cloudflare-ddns:
    image: favonia/cloudflare-ddns:latest
    network_mode: host
    restart: always
    container_name: cloudflare-ddns
    environment:
      CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN}
      DOMAINS: ${WG_HOST}
      PROXIED: 'false'
      UPDATE_CRON: "@every 1m"
      IP6_PROVIDER: 'none'
EOF

# Start the Docker Compose service using the new command
echo "Starting wg-easy container..."
docker compose up -d

echo "WireGuard Easy setup complete!"
