#!/bin/bash

# Create user and prompt for password
useradd -m -s /bin/bash kinhsman
echo "Please enter the password for user 'kinhsman':"
passwd kinhsman

# Add user to sudo group
usermod -aG sudo kinhsman

# Configure passwordless sudo for the user
echo "kinhsman ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kinhsman
chmod 0440 /etc/sudoers.d/kinhsman

# Enable SSH password authentication
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
systemctl restart ssh

echo "User 'kinhsman' created with sudo privileges and SSH password authentication enabled"
