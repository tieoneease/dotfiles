#!/usr/bin/env bash

# Script to update Slack desktop file to use Wayland natively
# This needs to be run after Slack updates to ensure the desktop file remains updated

set -euo pipefail

echo "Updating Slack desktop file for native Wayland support..."

# Create local applications directory if it doesn't exist
mkdir -p "$HOME/.local/share/applications"

# Check if the snap version of Slack desktop file exists
if [ -f "/var/lib/snapd/desktop/applications/slack_slack.desktop" ]; then
    # Copy the original desktop file
    cp "/var/lib/snapd/desktop/applications/slack_slack.desktop" "$HOME/.local/share/applications/"
    
    # Update the Exec line to use our Wayland wrapper
    sed -i "s|^Exec=.*|Exec=$HOME/.config/hypr/scripts/slack-wayland.sh %U|" \
        "$HOME/.local/share/applications/slack_slack.desktop"
    
    # Update Name to indicate it's running in Wayland mode
    sed -i "s|^Name=Slack|Name=Slack (Wayland)|" \
        "$HOME/.local/share/applications/slack_slack.desktop"
    
    echo "Desktop file successfully updated at $HOME/.local/share/applications/slack_slack.desktop"
else
    echo "Original Slack desktop file not found. Creating a new one..."
    
    # Create a new desktop file if the original doesn't exist
    cat > "$HOME/.local/share/applications/slack-wayland.desktop" << EOF
[Desktop Entry]
Name=Slack (Wayland)
Comment=Slack on Wayland
GenericName=Slack Client
Exec=$HOME/.config/hypr/scripts/slack-wayland.sh %U
Icon=slack
Type=Application
StartupNotify=true
Categories=Network;InstantMessaging;
EOF
    
    echo "New desktop file created at $HOME/.local/share/applications/slack-wayland.desktop"
fi

echo "Done! Slack will now run natively on Wayland."