#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[!]${NC} $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
fi

# Create SDDM configuration directory
print_status "Creating SDDM configuration directory..."
sudo mkdir -p /etc/sddm.conf.d/

# Check if Sugar Candy theme is installed
if [ ! -d "/usr/share/sddm/themes/sugar-candy" ]; then
    print_error "Sugar Candy theme not found. Please install it first with: paru -S sddm-theme-sugar-candy-git"
fi

# Copy theme configuration
print_status "Installing Sugar Candy theme configuration..."
sudo cp theme.conf /usr/share/sddm/themes/sugar-candy/theme.conf || print_error "Failed to copy theme configuration"

# Set Sugar Candy as default theme
print_status "Setting Sugar Candy as default theme..."
echo "[Theme]
Current=sugar-candy" | sudo tee /etc/sddm.conf.d/theme.conf || print_error "Failed to set default theme"

# Update faillock configuration
print_status "Updating faillock configuration..."
echo "dir = /var/run/faillock
deny = 5
fail_interval = 300
unlock_time = 60" | sudo tee /etc/security/faillock.conf || print_error "Failed to update faillock configuration"

# Set permissions
sudo chmod 644 /etc/sddm.conf.d/theme.conf
sudo chmod 644 /etc/security/faillock.conf

print_status "SDDM theme and faillock configuration updated successfully!"
print_status "You may need to restart SDDM for changes to take effect."
