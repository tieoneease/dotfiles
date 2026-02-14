#!/usr/bin/env bash
set -euo pipefail

# Toggle eDP-2 based on keyboard dock state
# USB ID 0b05:1b2c = ASUS Zenbook Duo 2024 Keyboard
# (2025 model uses 0b05:1bf2)

is_docked() {
    lsusb -d "0b05:1b2c" &>/dev/null
}

position_edp2_below() {
    # Niri uses ceiling for overlap detection but reports floor in JSON,
    # so add 1 to avoid silent overlap fallback to side-by-side placement
    local y
    y=$(niri msg -j outputs | jq -r '.["eDP-1"].logical.height + 1')
    niri msg output eDP-2 on
    niri msg output eDP-2 position set 0 "$y"
}

toggle_screen() {
    if is_docked; then
        niri msg output eDP-2 off
    else
        position_edp2_below
    fi
}

# Set initial state
toggle_screen

# Watch for USB events (pogo pins generate event storms, debounce with sleep)
stdbuf -oL udevadm monitor --subsystem-match=usb --udev 2>/dev/null | while read -r line; do
    case "$line" in
        *"add"*|*"remove"*)
            sleep 1
            toggle_screen
            ;;
    esac
done
