#!/bin/bash

set -e  # Exit on error

# Update and upgrade system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install required dependencies
echo "Installing required dependencies..."
apt install -y curl

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
echo "Installing Docker Compose..."
apt install -y docker-compose-plugin

# Prompt user for VPS domain and Cloudflare API token
read -p "Enter the public domain name or IP of the VPS: " WG_HOST
read -s -p "Enter your Cloudflare API Token: " CLOUDFLARE_API_TOKEN
echo ""  # Newline after silent input

# Create necessary directory for Docker Compose
mkdir -p /opt/wg-easy
cd /opt/wg-easy || exit

# Create docker-compose.yml file
cat <<EOF > docker-compose.yml
version: '3'

services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy
    restart: always
    environment:
      - LANG=en
      - WG_HOST=${WG_HOST}
      - PASSWORD_HASH=$$2a$$12$$o7iDxKq3rQHPhJ/JuqUZDu0pakCKhR4GBzsBxt/qO5yCkXWY2U1k2
      - PORT=51821
      - WG_PORT=65222
      - WG_DEFAULT_DNS=10.1.30.12, sangnetworks.com
    volumes:
      - ~/.wg-easy:/etc/wireguard
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

# Start the Docker Compose service
echo "Starting containers..."
docker compose up -d --force-recreate

echo "WireGuard Easy and Cloudflare DDNS setup complete!"
