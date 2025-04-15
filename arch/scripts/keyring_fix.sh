#!/usr/bin/env bash

# Script to diagnose and fix GNOME keyring issues
set -euo pipefail

echo "==== GNOME Keyring Diagnostic Tool ===="
echo

# Check if GNOME keyring daemon is running
echo "Checking if GNOME keyring daemon is running..."
if pgrep -f "gnome-keyring-daemon" > /dev/null; then
    echo "✅ GNOME keyring daemon is running"
else
    echo "❌ GNOME keyring daemon is NOT running"
    echo "Starting GNOME keyring daemon..."
    gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
fi

# Check SSH_AUTH_SOCK environment variable
echo
echo "Checking SSH_AUTH_SOCK environment variable..."
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
    echo "✅ SSH_AUTH_SOCK is set to: $SSH_AUTH_SOCK"
else
    echo "❌ SSH_AUTH_SOCK is NOT set"
    echo "Trying to find and set SSH_AUTH_SOCK..."
    export SSH_AUTH_SOCK=$(find /run/user/$(id -u) -name ssh | head -n 1)
    if [ -n "${SSH_AUTH_SOCK:-}" ]; then
        echo "✅ SSH_AUTH_SOCK is now set to: $SSH_AUTH_SOCK"
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo 'export SSH_AUTH_SOCK=$(find /run/user/$(id -u) -name ssh | head -n 1)'
    else
        echo "❌ Could not find SSH socket"
    fi
fi

# Check if python-oscrypto is installed
echo
echo "Checking if python-oscrypto is installed..."
if pacman -Q python-oscrypto &> /dev/null; then
    echo "✅ python-oscrypto is installed"
else
    echo "❌ python-oscrypto is NOT installed"
    echo "Installing python-oscrypto..."
    paru -S --needed python-oscrypto
fi

# Check DBUS session
echo
echo "Checking DBUS session..."
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "✅ DBUS_SESSION_BUS_ADDRESS is set"
else
    echo "❌ DBUS_SESSION_BUS_ADDRESS is NOT set"
    echo "This could prevent the keyring from working properly"
fi

# Check keyring service
echo
echo "Checking GNOME keyring systemd service..."
if systemctl --user is-active gnome-keyring.service &> /dev/null; then
    echo "✅ gnome-keyring.service is active"
else
    echo "❌ gnome-keyring.service is NOT active"
    echo "Enabling and starting gnome-keyring.service..."
    systemctl --user enable --now gnome-keyring.service
fi

# Test keyring
echo
echo "Testing keyring with secret-tool..."
if ! command -v secret-tool &> /dev/null; then
    echo "❌ secret-tool not found, installing libsecret..."
    paru -S --needed libsecret
fi

echo "Attempting to store and retrieve a test secret..."
secret-tool store --label="Keyring Test" test key test value &> /dev/null || echo "❌ Failed to store test secret"
if secret-tool lookup test key &> /dev/null; then
    echo "✅ Successfully stored and retrieved test secret"
    secret-tool clear test key &> /dev/null || echo "Warning: Could not clear test secret"
else
    echo "❌ Failed to retrieve test secret"
fi

echo
echo "==== Fixing common issues ===="

# Fix environment variables for Hyprland
echo "1. Ensuring proper environment variables for Hyprland..."
mkdir -p ~/.config/environment.d/
cat > ~/.config/environment.d/10-keyring.conf << EOF
SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-DEFAULT_SSH_AUTH_SOCK_VALUE}
EOF

# Fix PAM configuration if needed
echo "2. Checking PAM configuration..."
if ! grep -q pam_gnome_keyring.so /etc/pam.d/system-auth 2>/dev/null; then
    echo "PAM system-auth needs to be configured for GNOME keyring"
    echo "This requires sudo access. Run the arch_setup.sh script to fix this."
fi

# Make sure Gnome keyring autostart file exists
echo "3. Ensuring GNOME keyring autostart file exists..."
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/gnome-keyring-ssh.desktop << EOF
[Desktop Entry]
Type=Application
Name=GNOME Keyring: SSH Agent
Comment=GNOME Keyring: SSH Agent
Exec=/usr/bin/gnome-keyring-daemon --start --components=ssh
OnlyShowIn=GNOME;Unity;MATE;
X-GNOME-Autostart-Phase=PreDisplayServer
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Notify=true
X-GNOME-Bugzilla-Bugzilla=GNOME
X-GNOME-Bugzilla-Product=gnome-keyring
X-GNOME-Bugzilla-Component=general
X-GNOME-Bugzilla-Version=3.28.0.2
X-Ubuntu-Gettext-Domain=gnome-keyring
EOF

echo
echo "==== Diagnostic Complete ===="
echo "If you're still having issues:"
echo "1. Make sure to reboot your system"
echo "2. Check your display manager configuration"
echo "3. Ensure you have the correct PAM modules installed"
echo "4. Run the arch_setup.sh script to apply all necessary configurations"