#!/usr/bin/env bash
# Script to disable keyring for Chrome
set -euo pipefail

echo "==== Disabling Chrome Keyring Prompts ===="

# Chrome directory
CHROME_CONFIG="$HOME/.config/google-chrome"

# Check if Chrome directory exists
if [ ! -d "$CHROME_CONFIG" ]; then
    echo "Chrome config directory not found. Is Chrome installed?"
    exit 1
fi

# Find all Local State files
echo "Configuring Chrome to not use keyring..."
find "$CHROME_CONFIG" -name "Local State" | while read -r local_state; do
    # Backup the file
    cp "$local_state" "${local_state}.backup"
    
    # Disable OS integration in Chrome's password manager
    if jq -e '.os_crypt.use_os_crypt' "$local_state" > /dev/null; then
        echo "Disabling keyring integration in $local_state"
        jq '.os_crypt.use_os_crypt = false' "$local_state" > "${local_state}.tmp"
        mv "${local_state}.tmp" "$local_state"
    fi
done

# Remove environment variables related to keyring
if [ -f "$HOME/.config/environment.d/10-keyring.conf" ]; then
    echo "Removing keyring environment variables..."
    rm -f "$HOME/.config/environment.d/10-keyring.conf"
fi

if [ -f "$HOME/.pam_environment" ]; then
    echo "Cleaning up PAM environment file..."
    grep -v keyring "$HOME/.pam_environment" > "$HOME/.pam_environment.tmp"
    mv "$HOME/.pam_environment.tmp" "$HOME/.pam_environment"
fi

echo "==== Fix Complete ===="
echo "Please restart Chrome for changes to take effect."
echo "If you want to restore previous settings, use the .backup files created."