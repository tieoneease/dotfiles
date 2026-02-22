#!/usr/bin/env bash

set -euo pipefail

# Unified setup dispatcher — detects platform and runs the right script.
#
# Usage:
#   ./setup.sh          # auto-detect platform
#   ./setup.sh --vps    # force VPS (headless) mode

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# Check for --vps flag
VPS_FLAG=false
for arg in "$@"; do
    [[ "$arg" == "--vps" ]] && VPS_FLAG=true
done

if [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS"
    exec "$DOTFILES_DIR/macos_setup.sh"
elif [[ "$OS" == "Linux" ]]; then
    if $VPS_FLAG || [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        echo "Detected Linux (headless/VPS)"
        exec "$DOTFILES_DIR/vps_setup.sh"
    else
        echo "Detected Linux (desktop)"
        exec "$DOTFILES_DIR/arch_setup.sh"
    fi
else
    echo "Unsupported platform: $OS"
    exit 1
fi
