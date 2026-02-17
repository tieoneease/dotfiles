#!/usr/bin/env bash
set -euo pipefail
# Adjust brightness on the primary backlight and trigger Noctalia OSD.
#
# Niri's keybind intercepts XF86MonBrightness* before ACPI can handle it,
# so we always call brightnessctl ourselves, then notify the OSD.

# Find the primary backlight device: prefer intel_backlight / amdgpu_bl*,
# skip asus_* (WMI screenpad) and card* (DRM connector) devices.
primary=""
for dev in /sys/class/backlight/*; do
    [ -d "$dev" ] || continue
    name=$(basename "$dev")
    case "$name" in
        asus_*|card*) continue ;;
    esac
    primary="$dev"
    break
done

# Fallback: if no preferred device found, take the first one available
if [[ -z "$primary" ]]; then
    for dev in /sys/class/backlight/*; do
        [ -d "$dev" ] || continue
        primary="$dev"
        break
    done
fi

[[ -z "$primary" ]] && exit 0

# Apply the brightness change
brightnessctl -d "$(basename "$primary")" set "$1"

# Read current brightness and compute percentage
cur=$(cat "$primary/brightness")
max=$(cat "$primary/max_brightness")
pct=$(( cur * 100 / max ))

# Trigger Noctalia OSD
exec qs msg -c noctalia-shell brightness set "$pct"
