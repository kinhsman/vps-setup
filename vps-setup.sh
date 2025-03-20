#!/bin/bash

set -e

# Prompt user for VPS domain name
read -p "Enter the public domain name of the VPS: " WG_HOST

# Update and upgrade system packages
echo "Updating and upgrading system packages..."
apt update && apt upgrade -y

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
echo "Installing Docker Compose..."
apt install -y docker-compose-plugin

# Create directory for compose stack
echo "Creating directory /opt/wg-easy..."
mkdir -p /opt/wg-easy

# Create docker-compose.yml file
echo "Creating docker-compose.yml file..."
cat > /opt/wg-easy/docker-compose.yml <<EOL
services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy
    restart: always
    environment:
      - LANG=en
      - WG_HOST=${WG_HOST}
      - PASSWORD_HASH='$2a$12$686FwPj1VdtVYy2cR3aUF..8TTTBs.9eorN1FL/l1/duHazJa.hVS'
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
EOL

# Start the Docker Compose stack
echo "Starting wg-easy service using Docker Compose..."
docker compose -f /opt/wg-easy/docker-compose.yml up -d

echo "wg-easy deployment complete!"
