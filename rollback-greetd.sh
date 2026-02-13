#!/bin/bash
set -euo pipefail

# Rollback greetd setup -- restores autologin TTY boot.
#
# If greetd fails at boot, switch to another TTY (Ctrl+Alt+F2),
# log in, and run:  sudo bash ~/.config/rollback-greetd.sh

echo "=== Rolling back greetd setup ==="

echo "Disabling greetd.service..."
sudo systemctl disable greetd.service

echo "Re-adding chungsam to autologin group..."
sudo gpasswd -a chungsam autologin

echo "Restoring default greetd config (agreety)..."
sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
vt = 1

[default_session]
command = "agreety --cmd /bin/bash"
user = "greeter"
EOF

echo ""
echo "=== Rollback complete ==="
echo "greetd is disabled; autologin group restored."
echo "Reboot to return to your previous boot flow."
