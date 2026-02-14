#!/usr/bin/env bash
set -euo pipefail
# Set brightness on all backlight devices (skips asus_* WMI duplicates)
for dev in /sys/class/backlight/*; do
    name=$(basename "$dev")
    [[ "$name" == asus_* ]] && continue
    brightnessctl -d "$name" set "$1"
done
