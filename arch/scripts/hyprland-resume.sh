#!/usr/bin/env bash
# Simple script to reload Hyprland after resume
# Source: https://github.com/hyprwm/Hyprland/issues discussions

# Sleep briefly to ensure system is fully resumed
sleep 2

# Make sure WAYLAND_DISPLAY is set
if [ -z "$WAYLAND_DISPLAY" ]; then
  export WAYLAND_DISPLAY=wayland-0
fi

# Find user ID who is running Hyprland
USER_ID=$(pgrep -f Hyprland | xargs -I{} ps -o uid= -p {})
USER_NAME=$(id -nu "$USER_ID")

# Run hyprctl reload as that user
runuser -l "$USER_NAME" -c "WAYLAND_DISPLAY=$WAYLAND_DISPLAY hyprctl reload"

exit 0