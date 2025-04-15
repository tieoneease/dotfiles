#!/usr/bin/env bash
# Script to fix GNOME keyring storage issues
set -euo pipefail

# Check if running as root, which we don't want
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: This script should NOT be run as root!"
    echo "Please run this script as your regular user without sudo"
    exit 1
fi

echo "==== Fixing GNOME Keyring Storage Issues ===="

# Check dependencies
echo "Checking dependencies..."
for pkg in gnome-keyring libsecret seahorse python-oscrypto python-gobject; do
    if ! paru -Q "$pkg" &> /dev/null; then
        echo "Installing $pkg..."
        paru -S --needed "$pkg"
    else
        echo "✅ $pkg is installed"
    fi
done

# Create keyring directory
echo "Ensuring keyring directory exists..."
mkdir -p ~/.local/share/keyrings

# Reset keyring if it's corrupted
echo "Would you like to reset the login keyring? (This will remove all stored passwords) [y/N]: "
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Resetting login keyring..."
    rm -f ~/.local/share/keyrings/login.keyring
    echo "Login keyring has been reset."
fi

# Fix DBus session
echo "Setting up DBus session..."
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    # Try to get existing dbus session
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    
    # If still not available, start a new one
    if ! dbus-send --session --dest=org.freedesktop.DBus \
        --type=method_call --print-reply /org/freedesktop/DBus \
        org.freedesktop.DBus.ListNames > /dev/null 2>&1; then
        echo "Starting new DBus session..."
        eval "$(dbus-launch --sh-syntax)"
        echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" 
        echo "DBUS_SESSION_BUS_PID=$DBUS_SESSION_BUS_PID"
    fi
fi

# Restart keyring daemon
echo "Restarting keyring daemon..."
killall -q gnome-keyring-daemon || true
export GNOME_KEYRING_CONTROL="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring"
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh

# Setup environment variables
echo "Setting up environment variables..."
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    runtime_dir="$XDG_RUNTIME_DIR"
else
    runtime_dir="/run/user/$(id -u)"
fi

cat > ~/.pam_environment << EOF
SSH_AUTH_SOCK DEFAULT="${runtime_dir}/keyring/ssh"
EOF

# Create environment.d configuration
mkdir -p ~/.config/environment.d/
cat > ~/.config/environment.d/10-keyring.conf << EOF
SSH_AUTH_SOCK=${runtime_dir}/keyring/ssh
EOF

# Create simple script to unlock keyring
echo "Creating unlock script..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/unlock-keyring.sh << 'EOF'
#!/usr/bin/env bash
# Simple script to unlock the GNOME keyring
set -e

# First try python method if python-gobject is installed
if command -v python &> /dev/null && python -c "import gi" &> /dev/null; then
    python -c "
try:
    from gi.repository import Secret
    Secret.Service.open_sync(Secret.ServiceFlags.LOAD_COLLECTIONS)
    print('Keyring unlocked via Secret API')
except Exception as e:
    print(f'Error unlocking keyring via Secret API: {e}')
"
fi

# Try with secret-tool as fallback
if command -v secret-tool &> /dev/null; then
    # Attempt to lookup a dummy key to trigger unlock
    secret-tool lookup dummy key &> /dev/null || true
    echo "Attempted keyring unlock via secret-tool"
fi

# Ensure gnome-keyring-daemon is running
pkill -0 gnome-keyring-daemon || {
    gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
    echo "Started gnome-keyring-daemon"
}

exit 0
EOF

chmod +x ~/.local/bin/unlock-keyring.sh

# Create systemd unit to unlock keyring on login
echo "Setting up systemd user service..."
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/keyring-unlock.service << EOF
[Unit]
Description=Unlock GNOME keyring on login
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/home/$(whoami)/.local/bin/unlock-keyring.sh
Restart=no

[Install]
WantedBy=graphical-session.target
EOF

# Enable the service
echo "Enabling systemd user service..."
systemctl --user daemon-reload
systemctl --user enable --now keyring-unlock.service

# Fix permissions
echo "Fixing keyring permissions..."
chmod -R 700 ~/.local/share/keyrings
chmod 700 ~/.config/systemd/user/keyring-unlock.service

# Configure automatic unlock
echo "Setting up automatic unlock on login..."
cat > ~/.config/autostart/gnome-keyring-secrets.desktop << EOF
[Desktop Entry]
Type=Application
Name=GNOME Keyring Secrets
Comment=GNOME Keyring Secret Service
Exec=/usr/bin/gnome-keyring-daemon --start --components=secrets
EOF

# Test keyring
echo "Testing keyring..."
echo "Trying to store a test secret..."

# Ensure we have dbus session and keyring control environment variables
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "Warning: DBUS_SESSION_BUS_ADDRESS not set, test may fail"
fi

if [ -z "${GNOME_KEYRING_CONTROL:-}" ]; then
    echo "Warning: GNOME_KEYRING_CONTROL not set, test may fail"
fi

# Attempt to store and retrieve a secret
set +e  # Don't exit on error
secret-tool store --label="Test Secret" test key test-value > /dev/null 2>&1
secret_store_result=$?

if [ $secret_store_result -eq 0 ]; then
    echo "Successfully stored test secret"
    
    if secret-tool lookup test key > /dev/null 2>&1; then
        echo "✅ Successfully retrieved test secret"
        secret-tool clear test key > /dev/null 2>&1 || echo "Warning: Could not clear test secret"
    else
        echo "❌ Failed to retrieve secret (storage succeeded but retrieval failed)"
    fi
else
    echo "❌ Failed to store test secret (error code: $secret_store_result)"
fi

set -e  # Back to normal error handling

echo
echo "==== Fix Complete ===="
echo "Please reboot your system for all changes to take effect"
echo "After reboot, run the keyring_fix.sh script again to verify everything is working"