#!/usr/bin/env bash
set -euo pipefail

# Toggle eDP-2 based on keyboard dock state
# USB ID 0b05:1b2c = ASUS Zenbook Duo 2024 Keyboard
# (2025 model uses 0b05:1bf2)

NIRI_CONFIG_DIR="$HOME/.config/niri"
ZENBOOK_HOSTNAME="sam-duomoon"

# Write file atomically via temp+rename to avoid niri seeing truncated/partial content
write_atomic() {
    local target="$1"
    local tmp
    tmp=$(mktemp "${target}.XXXXXX")
    cat > "$tmp"
    mv -f "$tmp" "$target"
}

# Generate single-monitor defaults if include files don't exist yet.
# Ensures non-Zenbook devices get valid include files on first boot.
generate_defaults() {
    if [[ ! -f "$NIRI_CONFIG_DIR/monitor-workspaces.kdl" ]]; then
        write_atomic "$NIRI_CONFIG_DIR/monitor-workspaces.kdl" << 'EOF'
workspace "󰊯"
workspace "󰭹"
workspace "󰆍"
workspace "󰈙"
workspace ""
workspace "󰄨"
workspace "󰍉"
workspace ""
workspace "󰳪"
EOF
    fi
    if [[ ! -f "$NIRI_CONFIG_DIR/monitor-nav.kdl" ]]; then
        printf 'binds {\n    Alt+J { focus-window-or-workspace-down; }\n    Alt+K { focus-window-or-workspace-up; }\n}\n' | write_atomic "$NIRI_CONFIG_DIR/monitor-nav.kdl"
    fi
}

generate_defaults

# Only run dock/undock logic on the Zenbook Duo
if [[ "$(hostname)" != "$ZENBOOK_HOSTNAME" ]]; then
    exit 0
fi

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

# Write Alt+J/K binds — monitor navigation when undocked, window/workspace when docked.
# Niri auto-reloads on file change, so bindings swap instantly.
write_nav_binds() {
    local f="$NIRI_CONFIG_DIR/monitor-nav.kdl"
    if is_docked; then
        printf 'binds {\n    Alt+J { focus-window-or-workspace-down; }\n    Alt+K { focus-window-or-workspace-up; }\n}\n' | write_atomic "$f"
    else
        printf 'binds {\n    Alt+J { focus-monitor-down; }\n    Alt+K { focus-monitor-up; }\n}\n' | write_atomic "$f"
    fi
}

# Write workspace declarations — 9 named workspaces when docked,
# 18 (9 per monitor with different icons) when undocked.
write_workspace_config() {
    local f="$NIRI_CONFIG_DIR/monitor-workspaces.kdl"
    if is_docked; then
        write_atomic "$f" << 'EOF'
workspace "󰊯"
workspace "󰭹"
workspace "󰆍"
workspace "󰈙"
workspace ""
workspace "󰄨"
workspace "󰍉"
workspace ""
workspace "󰳪"
EOF
    else
        write_atomic "$f" << 'EOF'
// eDP-1 (top screen)
workspace "󰊯" { open-on-output "eDP-1"; }
workspace "󰭹" { open-on-output "eDP-1"; }
workspace "󰆍" { open-on-output "eDP-1"; }
workspace "󰈙" { open-on-output "eDP-1"; }
workspace "" { open-on-output "eDP-1"; }
workspace "󰄨" { open-on-output "eDP-1"; }
workspace "󰍉" { open-on-output "eDP-1"; }
workspace "" { open-on-output "eDP-1"; }
workspace "󰳪" { open-on-output "eDP-1"; }

// eDP-2 (bottom screen)
workspace "1" { open-on-output "eDP-2"; }
workspace "2" { open-on-output "eDP-2"; }
workspace "3" { open-on-output "eDP-2"; }
workspace "4" { open-on-output "eDP-2"; }
workspace "5" { open-on-output "eDP-2"; }
workspace "6" { open-on-output "eDP-2"; }
workspace "7" { open-on-output "eDP-2"; }
workspace "8" { open-on-output "eDP-2"; }
workspace "9" { open-on-output "eDP-2"; }
EOF
    fi
}

# Apply monitor state and regenerate config includes
apply_dock_state() {
    toggle_screen
    write_nav_binds
    write_workspace_config
    niri msg action load-config-file 2>/dev/null || true
}

# Set initial state
apply_dock_state

# Watch for USB events (pogo pins generate event storms, drain-based debounce)
stdbuf -oL udevadm monitor --subsystem-match=usb --udev 2>/dev/null | while read -r line; do
    case "$line" in
        *"add"*|*"remove"*)
            while read -r -t 1 _; do :; done
            apply_dock_state
            ;;
    esac
done
