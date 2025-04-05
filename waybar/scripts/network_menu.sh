#!/usr/bin/env bash

# Script to handle network management using iwd (iwctl)

# Check if foot terminal is available
if command -v foot >/dev/null 2>&1; then
    foot -e iwctl
else
    # Fallback to any available terminal
    for term in kitty alacritty termite xterm; do
        if command -v $term >/dev/null 2>&1; then
            $term -e iwctl
            exit 0
        fi
    done
    
    # If no terminal is found, notify the user
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Error" "No terminal emulator found to launch iwctl"
    else
        echo "Error: No terminal emulator found to launch iwctl" >&2
    fi
fi