#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting VPS setup...${NC}"

# Function to wait for apt lock
wait_for_apt() {
    local timeout=120  # Wait up to 120 seconds
    local counter=0
    while [ -f /var/lib/dpkg/lock-frontend ] || [ -f /var/lib/apt/lists/lock ] || [ -f /var/cache/apt/archives/lock ]; do
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}Error: Could not acquire apt lock after $timeout seconds. Another process may be using apt.${NC}"
            echo "Please check for running apt processes with 'ps aux | grep apt' and resolve the conflict."
            exit 1
        fi
        echo "Waiting for apt lock to be released... ($counter/$timeout seconds)"
        sleep 1
        counter=$((counter + 1))
    done
}

# 1. Stop automatic updates to prevent apt lock conflicts
echo "Stopping automatic updates (if running)..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true

# 2. Check and fix dpkg interruptions
echo "Checking for dpkg interruptions..."
if ! sudo dpkg --configure -a; then
    echo -e "${RED}Error: Failed to resolve dpkg interruptions. Please run 'sudo dpkg --configure -a' manually and check for errors.${NC}"
    exit 1
fi

# 3. Update and upgrade packages silently
echo "Updating and upgrading packages..."
# Wait for apt lock to be released
wait_for_apt
# Set noninteractive mode to avoid prompts
export DEBIAN_FRONTEND=noninteractive
# Pre-configure dpkg to keep the current configuration files
echo "openssh-server openssh-server/permit-root-login boolean true" | debconf-set-selections
sudo apt update
# Use -y for automatic yes, and -o options to avoid config file prompts
sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 4. Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

# 5. Install Tailscale
echo "Installing Tailscale..."

# Check if TAILSCALE_AUTH_KEY is provided as an environment variable
if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    # If running interactively, prompt for the auth key
    if [ -t 0 ]; then
        echo -e "${GREEN}Please enter your Tailscale auth key:${NC}"
        read -p "Auth key: " TAILSCALE_AUTH_KEY
    else
        echo -e "${RED}Error: TAILSCALE_AUTH_KEY environment variable not set and script is running non-interactively.${NC}"
        echo "Please set the TAILSCALE_AUTH_KEY environment variable and try again."
        echo "Example: TAILSCALE_AUTH_KEY=your-auth-key curl -fsSL <script-url> | sh"
        exit 1
    fi
fi

curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --accept-routes=true

# 6. Create directory for wg-easy
echo "Creating directory structure..."
sudo mkdir -p /opt/wg-easy
cd /opt/wg-easy

# 7. Get server IP/domain
# Check if SERVER_HOST is provided as an environment variable
if [ -z "$SERVER_HOST" ]; then
    # If running interactively, prompt for the server host
    if [ -t 0 ]; then
        echo -e "${GREEN}Please enter your server's public domain name or IP:${NC}"
        read -p "Server domain/IP: " SERVER_HOST
    else
        echo -e "${RED}Error: SERVER_HOST environment variable not set and script is running non-interactively.${NC}"
        echo "Please set the SERVER_HOST environment variable and try again."
        echo "Example: SERVER_HOST=your-server-ip curl -fsSL <script-url> | sh"
        exit 1
    fi
fi

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

# 8. Run the container
echo "Starting wg-easy container..."
docker compose up -d

echo -e "${GREEN}Setup complete!${NC}"
echo "wg-easy should now be running on port 51821"
echo "Access it at: http://${SERVER_HOST}:51821"
echo "Default password is encrypted in the config - use the corresponding plaintext password"

# 9. Re-enable automatic updates (optional)
echo "Re-enabling automatic updates..."
sudo systemctl enable unattended-upgrades || true
sudo systemctl start unattended-upgrades || true
