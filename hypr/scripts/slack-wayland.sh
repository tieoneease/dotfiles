#!/usr/bin/env bash

# Script to launch Slack with Wayland native support
# This script forces Electron to use Wayland instead of XWayland

# Ensure required environment variables are set
export WAYLAND_DISPLAY=wayland-1
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM=wayland
export CLUTTER_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export MOZ_ENABLE_WAYLAND=1

# Launch Slack with Wayland flags
exec /snap/bin/slack --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer,WaylandWindowDecorations --ozone-platform=wayland "$@"