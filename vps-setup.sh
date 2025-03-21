#!/bin/bash

set -e  # Exit on error

# Function to validate input
validate_input() {
    if [[ -z "$WG_HOST" ]]; then
        echo "Error: Domain name or IP cannot be empty"
        exit 1
    fi
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        echo "Error: Cloudflare API token cannot be empty"
        exit 1
    fi
    if [[ -z "$WG_PASSWORD" ]]; then
        echo "Error: Password cannot be empty"
        exit 1
    fi
}

# Prompt user for input at the beginning
echo "Enter the public domain name or IP of the VPS:"
read -p "Domain/IP: " WG_HOST
echo "Enter your Cloudflare API Token (input will be hidden):"
read -s -p "Token: " CLOUDFLARE_API_TOKEN
echo -e "\n"  # Ensure newline after silent input
echo "Enter the password for wg-easy (input will be hidden):"
read -s -p "Password: " WG_PASSWORD
echo -e "\n"  # Ensure newline after silent input

# Validate the inputs
validate_input

# Update and upgrade system packages
echo "Updating system packages..."
if ! apt update || ! DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
    echo "Error: Failed to update system packages"
    exit 1
fi

# Install required dependencies
echo "Installing required dependencies..."
if ! apt install -y curl; then
    echo "Error: Failed to install dependencies"
    exit 1
fi

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    if ! curl -fsSL https://get.docker.com | sh; then
        echo "Error: Failed to install Docker"
        exit 1
    fi
else
    echo "Docker is already installed."
fi

# Install docker-compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing docker-compose..."
    if ! apt install -y docker-compose; then
        echo "Error: Failed to install docker-compose"
        exit 1
    fi
else
    echo "docker-compose is already installed."
fi

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Starting Docker service..."
    if ! systemctl start docker; then
        echo "Error: Failed to start Docker service"
        exit 1
    fi
fi

# Create necessary directory with error handling
echo "Creating configuration directory..."
if ! mkdir -p /opt/wg-easy/wg-data 2>/dev/null; then
    echo "Error: Failed to create directory /opt/wg-easy/wg-data"
    exit 1
fi
if ! chmod 700 /opt/wg-easy/wg-data; then
    echo "Error: Failed to set directory permissions"
    exit 1
fi
if ! cd /opt/wg-easy; then
    echo "Error: Failed to change to directory /opt/wg-easy"
    exit 1
fi

# Create docker-compose.yml file with user-provided PASSWORD
echo "Creating docker-compose configuration..."
cat <<EOF > docker-compose.yml
services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy
    restart: always
    environment:
      - LANG=en
      - WG_HOST=${WG_HOST}
      - PASSWORD=${WG_PASSWORD}
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

# Check if docker-compose file was created successfully
if [[ ! -f docker-compose.yml ]]; then
    echo "Error: Failed to create docker-compose.yml"
    exit 1
fi

# Start the Docker Compose service
echo "Starting wg-easy and cloudflare-ddns containers..."
if ! docker compose up -d; then
    echo "Error: Failed to start containers"
    exit 1
fi

echo "WireGuard Easy setup completed successfully!"
echo "Access the web interface at http://${WG_HOST}:51821"
echo "Login using the password you provided"
echo "WireGuard VPN is running on port 65222/UDP"
