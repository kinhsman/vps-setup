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
}

# Prompt user for input at the beginning
echo "Enter the public domain name or IP of the VPS:"
read -p "Domain/IP: " WG_HOST
echo "Enter your Cloudflare API Token (input will be hidden):"
read -s -p "Token: " CLOUDFLARE_API_TOKEN
echo -e "\n"  # Ensure newline after silent input

# Validate the inputs
validate_input

# Update system packages
echo "Updating system packages..."
if ! apt update; then
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

# Stop and remove any existing containers
echo "Cleaning up any existing containers..."
docker stop wg-easy cloudflare-ddns 2>/dev/null || true
docker rm wg-easy cloudflare-ddns 2>/dev/null || true

# Run wg-easy container
echo "Starting wg-easy container..."
if ! docker run -d \
    --name wg-easy \
    --restart always \
    -e LANG=en \
    -e WG_HOST="${WG_HOST}" \
    -e PASSWORD_HASH='$2a$12$o7iDxKq3rQHPhJ/JuqUZDu0pakCKhR4GBzsBxt/qO5yCkXWY2U1k2' \
    -e PORT=51821 \
    -e WG_PORT=65222 \
    -e WG_DEFAULT_DNS="10.1.30.12, sangnetworks.com" \
    -v /opt/wg-easy/wg-data:/etc/wireguard \
    -p 65222:65222/udp \
    -p 51821:51821/tcp \
    --cap-add NET_ADMIN \
    --cap-add SYS_MODULE \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv4.ip_forward=1 \
    ghcr.io/wg-easy/wg-easy; then
    echo "Error: Failed to start wg-easy container"
    exit 1
fi

# Run cloudflare-ddns container
echo "Starting cloudflare-ddns container..."
if ! docker run -d \
    --name cloudflare-ddns \
    --restart always \
    --network host \
    -e CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}" \
    -e DOMAINS="${WG_HOST}" \
    -e PROXIED="false" \
    -e UPDATE_CRON="@every 1m" \
    -e IP6_PROVIDER="none" \
    favonia/cloudflare-ddns:latest; then
    echo "Error: Failed to start cloudflare-ddns container"
    exit 1
fi

echo "WireGuard Easy setup completed successfully!"
echo "Access the web interface at http://${WG_HOST}:51821 or http://${hostname}:51821"
echo "WireGuard VPN is running on port 65222/UDP"
