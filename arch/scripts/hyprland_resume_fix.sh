#!/usr/bin/env bash
# Script to reset Hyprland input state after suspend
set -euo pipefail

# Check if Hyprland is running
if pgrep -x Hyprland >/dev/null; then
    echo "Reloading Hyprland input configuration"
    sleep 1  # Give the system a moment to fully resume
    hyprctl reload
fi

exit 0