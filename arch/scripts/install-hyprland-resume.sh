#!/usr/bin/env bash
# Install Hyprland resume service
set -euo pipefail

# Copy the script to a system directory
sudo cp "$(dirname "$0")/hyprland-resume.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/hyprland-resume.sh

# Create systemd service file
cat <<EOF | sudo tee /etc/systemd/system/hyprland-resume.service > /dev/null
[Unit]
Description=Reload Hyprland after resume
After=suspend.target
After=hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hyprland-resume.sh

[Install]
WantedBy=suspend.target
WantedBy=hibernate.target
EOF

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable hyprland-resume.service

echo "Hyprland resume service installed and enabled"
echo "Workspace shortcuts should now work after suspend"