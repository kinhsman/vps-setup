#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting VPS setup...${NC}"

# 1. Update and upgrade packages silently
echo "Updating and upgrading packages..."
# Set noninteractive mode to avoid prompts
export DEBIAN_FRONTEND=noninteractive
# Pre-configure dpkg to keep the current configuration files
echo "openssh-server openssh-server/permit-root-login boolean true" | debconf-set-selections
sudo apt update
# Use -y for automatic yes, and -o options to avoid config file prompts
sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 2. Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

# 3. Install Tailscale and prompt for auth key
echo "Installing Tailscale..."
echo -e "${GREEN}Please enter your Tailscale auth key:${NC}"
read -p "Auth key: " TAILSCALE_AUTH_KEY
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --accept-routes

# 4. Create directory for wg-easy
echo "Creating directory structure..."
sudo mkdir -p /opt/wg-easy
cd /opt/wg-easy

# 5. Prompt for server IP/domain and create compose file
echo -e "${GREEN}Please enter your server's public domain name or IP:${NC}"
read -p "Server domain/IP: " SERVER_HOST

echo "Creating docker-compose file..."
cat > docker-compose.yml << EOF
version: '3.8'
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    environment:
      - LANG=en
      - WG_HOST=${SERVER_HOST}
      - PASSWORD_HASH=\$2a\$12\$U4fGrxUj/5tWxiloYKwAju8/ivq8bvyuCcur5Ffhr22UrOuLsl4li
      - PORT=51821
      - WG_PORT=65222
      - WG_DEFAULT_DNS=10.1.30.12, sangnetworks.com
    volumes:
      - ~/.wg-easy:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    restart: always
EOF

# Ensure the wg-easy volume directory exists
mkdir -p ~/.wg-easy

# Run the container
echo "Starting wg-easy container..."
docker compose up -d

echo -e "${GREEN}Setup complete!${NC}"
echo "wg-easy should now be running on port 51821"
echo "Access it at: http://${SERVER_HOST}:51821"
echo "Default password is encrypted in the config - use the corresponding plaintext password"
