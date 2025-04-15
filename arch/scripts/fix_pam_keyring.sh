#!/usr/bin/env bash
# Script to fix PAM configuration for GNOME keyring
set -euo pipefail

echo "Configuring system-auth for GNOME keyring..."

# Add before the last session line
if ! grep -q "pam_gnome_keyring.so auto_start" /etc/pam.d/system-auth; then
    sudo sed -i '/^session.*optional.*pam_permit.so/i session    optional     pam_gnome_keyring.so auto_start' /etc/pam.d/system-auth
    echo "Added session configuration"
fi

# Add after the last auth line
if ! grep -q "^auth.*optional.*pam_gnome_keyring.so" /etc/pam.d/system-auth; then
    sudo sed -i '/^auth.*optional.*pam_permit.so/a auth       optional     pam_gnome_keyring.so' /etc/pam.d/system-auth
    echo "Added auth configuration"
fi

# Add after the last password line
if ! grep -q "^password.*optional.*pam_gnome_keyring.so" /etc/pam.d/system-auth; then
    sudo sed -i '/^password.*optional.*pam_permit.so/a password   optional     pam_gnome_keyring.so' /etc/pam.d/system-auth
    echo "Added password configuration"
fi

echo "Checking if additional PAM files need to be configured..."

# Ensure display manager configuration
for dm_conf in /etc/pam.d/gdm /etc/pam.d/gdm-password /etc/pam.d/lightdm /etc/pam.d/sddm; do
    if [ -f "$dm_conf" ]; then
        echo "Checking $dm_conf..."
        if ! grep -q "pam_gnome_keyring.so auto_start" "$dm_conf"; then
            echo "Configuring $dm_conf..."
            sudo sed -i '/^@include.*system-auth/a session    optional     pam_gnome_keyring.so auto_start' "$dm_conf"
            sudo sed -i '/^auth.*include.*system-auth/a auth       optional     pam_gnome_keyring.so' "$dm_conf"
        fi
    fi
done

# Ensure ly is configured
ly_conf="/etc/pam.d/ly"
if [ -f "$ly_conf" ]; then
    echo "Checking $ly_conf..."
    if ! grep -q "pam_gnome_keyring.so auto_start" "$ly_conf"; then
        echo "Configuring $ly_conf..."
        echo "auth       optional     pam_gnome_keyring.so" | sudo tee -a "$ly_conf" > /dev/null
        echo "session    optional     pam_gnome_keyring.so auto_start" | sudo tee -a "$ly_conf" > /dev/null
    fi
fi

# Additional fixes
echo "Setting up keyring for unlock on login..."

# Configure GNOME keyring to unlock on login
if [ -d "/etc/xdg/autostart" ]; then
    for file in /usr/share/applications/gnome-keyring-*.desktop; do
        if [ -f "$file" ]; then
            sudo cp "$file" /etc/xdg/autostart/
            echo "Copied $(basename "$file") to /etc/xdg/autostart/"
        fi
    done
fi

# Make sure gnome-keyring is installed
if ! paru -Q gnome-keyring &> /dev/null; then
    echo "Installing gnome-keyring package..."
    paru -S --needed gnome-keyring
fi

echo "PAM configuration complete. You'll need to restart or logout/login for changes to take effect."
