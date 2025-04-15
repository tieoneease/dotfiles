# GNOME Keyring Troubleshooting Guide for Hyprland

This guide will help you fix GNOME keyring issues on Arch Linux with Hyprland.

## Common Issues

1. Applications can't find or access the keyring
2. Keyring doesn't unlock automatically at login
3. DBus connection errors
4. Keyring control socket not found

## Step-by-step Fix

### 1. Make sure required packages are installed

```bash
paru -S gnome-keyring libsecret seahorse python-oscrypto
```

### 2. Fix PAM configuration (run as root)

```bash
sudo ./fix_pam_keyring.sh
```

This script will:
- Configure PAM to handle GNOME keyring properly
- Set up automatic keyring unlock
- Add keyring configuration to your display manager

### 3. Fix keyring storage (run as regular user, NOT root)

```bash
./fix_keyring_storage.sh
```

This script will:
- Set up DBus session
- Configure environment variables
- Set up keyring daemon
- Test keyring functionality

### 4. Verify Hyprland Configuration

Make sure your Hyprland configuration (`~/.config/hypr/hyprland.conf`) has the following lines:

```
# Set up DBus and environment variables
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = dbus-update-activation-environment --systemd --all
exec-once = dbus-launch --sh-syntax --exit-with-session
exec-once = /usr/bin/gnome-keyring-daemon --start --foreground --components=pkcs11,secrets,ssh
exec-once = systemctl --user restart gnome-keyring.service
```

### 5. Create systemd user service

```bash
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/gnome-keyring.service << EOF
[Unit]
Description=GNOME Keyring daemon
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/gnome-keyring-daemon --start --foreground --components=secrets,ssh,pkcs11
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now gnome-keyring.service
```

### 6. Reboot and test

After implementing all the fixes, reboot your system:

```bash
sudo reboot
```

After reboot, test the keyring:

```bash
./keyring_fix.sh
```

## Manual Debug Steps

If issues persist, try these manual steps:

1. Check if GNOME keyring daemon is running:
```bash
ps aux | grep gnome-keyring
```

2. Check environment variables:
```bash
echo $GNOME_KEYRING_CONTROL
echo $SSH_AUTH_SOCK
echo $DBUS_SESSION_BUS_ADDRESS
```

3. Test keyring manually:
```bash
secret-tool store --label="Test Secret" test key test-value
secret-tool lookup test key
```

4. Check logs:
```bash
journalctl --user -u gnome-keyring
```

## Common Error Messages and Solutions

### "couldn't connect to dbus session bus"

This means DBus is not properly configured. Fix:
```bash
eval $(dbus-launch --sh-syntax)
export $(gnome-keyring-daemon --start)
```

### "couldn't access control socket"

This means the keyring daemon isn't running or accessible. Fix:
```bash
rm -rf ~/.local/share/keyrings/*
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
```

### "No such schema" (for Seahorse users)

Install the required schema:
```bash
paru -S gnome-keyring gnome-themes-extra
```