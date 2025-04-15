#!/usr/bin/env bash
# Setup Hyprland resume service
set -euo pipefail

# Copy the script to local bin
mkdir -p ~/.local/bin
cp "$(dirname "$0")/hyprland_resume_fix.sh" ~/.local/bin/
chmod +x ~/.local/bin/hyprland_resume_fix.sh

# Create systemd user service
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/hyprland-resume.service << EOF
[Unit]
Description=Reset Hyprland input after resume
After=suspend.target
After=hibernate.target
After=hybrid-sleep.target

[Service]
Type=oneshot
ExecStart=/home/$(whoami)/.local/bin/hyprland_resume_fix.sh
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0

[Install]
WantedBy=suspend.target
WantedBy=hibernate.target
WantedBy=hybrid-sleep.target
EOF

# Enable the service
systemctl --user daemon-reload
systemctl --user enable hyprland-resume.service

echo "Hyprland resume fix service has been installed and enabled"
echo "Your workspace shortcuts should now work correctly after suspend"