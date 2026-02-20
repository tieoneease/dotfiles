#!/usr/bin/env bash
set -euo pipefail

# Toggle eDP-2 based on keyboard dock state
# USB ID 0b05:1b2c = ASUS Zenbook Duo 2024 Keyboard
# (2025 model uses 0b05:1bf2)

NIRI_CONFIG_DIR="$HOME/.config/niri"
DEVICE_CONFIG_DIR="$NIRI_CONFIG_DIR/devices"
ZENBOOK_HOSTNAME="sam-duomoon"

# Workspace icon arrays — single source of truth for intended ordering.
# Used by ensure_workspace_config() on first-time creation to declare all 18
# workspaces, then reorder them via IPC (niri prepends new workspaces at index 0).
# During steady-state dock/undock, niri preserves workspace order natively.
EDP1_WORKSPACES=("󰇧" "󰭹" "󰆍" "󰈚" "󰅴" "󰄨" "󰍉" "󰧑" "󰳪")
EDP2_WORKSPACES=("󰖟" "󰍡" "󰞷" "󰧭" "󰘦" "󱁉" "󱎸" "󰠮" "󰂓")

# Write file atomically via temp+rename to avoid niri seeing truncated/partial content
write_atomic() {
    local target="$1"
    local tmp
    tmp=$(mktemp "${target}.XXXXXX")
    cat > "$tmp"
    mv -f "$tmp" "$target"
}

# Reorder named workspaces to their intended positions after config reload.
# Niri prepends newly-declared workspaces to index 0 on reload, scrambling order.
# This function uses move-workspace-to-index IPC to set positions deterministically.
# The command is per-monitor, so eDP-1 and eDP-2 workspace names don't collide.
reorder_workspaces() {
    local i=1
    for name in "$@"; do
        niri msg action move-workspace-to-index "$i" --reference "$name" 2>/dev/null || true
        ((i++))
    done
}

# Generate include-file defaults if they don't exist yet.
# Workspace config: non-Zenbook gets 9 single-monitor workspaces here;
# Zenbook gets 18 dual-monitor workspaces via ensure_workspace_config() later.
generate_defaults() {
    if [[ "$(hostname)" != "$ZENBOOK_HOSTNAME" ]] && [[ ! -f "$NIRI_CONFIG_DIR/monitor-workspaces.kdl" ]]; then
        local f="$NIRI_CONFIG_DIR/monitor-workspaces.kdl"
        local ws
        {
            for ws in "${EDP1_WORKSPACES[@]}"; do
                printf 'workspace "%s"\n' "$ws"
            done
        } | write_atomic "$f"
    fi
    if [[ ! -f "$NIRI_CONFIG_DIR/monitor-nav.kdl" ]]; then
        printf 'binds {\n    Alt+J { focus-window-or-workspace-down; }\n    Alt+K { focus-window-or-workspace-up; }\n}\n' | write_atomic "$NIRI_CONFIG_DIR/monitor-nav.kdl"
    fi
    if [[ ! -f "$NIRI_CONFIG_DIR/device-outputs.kdl" ]]; then
        local device_file="$DEVICE_CONFIG_DIR/$(hostname).kdl"
        if [[ -f "$device_file" ]]; then
            cp "$device_file" "$NIRI_CONFIG_DIR/device-outputs.kdl"
        fi
    fi
}

# Ensure the 18-workspace config with open-on-output constraints exists.
# Skips if already correct (grep for eDP-2 marker). On first creation or
# upgrade from 9-workspace default, writes the file, reloads, and reorders
# via IPC (new workspaces get prepended at index 0).
ensure_workspace_config() {
    local f="$NIRI_CONFIG_DIR/monitor-workspaces.kdl"
    [[ -f "$f" ]] && grep -q 'open-on-output "eDP-2"' "$f" && return
    write_atomic "$f" << 'EOF'
// eDP-1 (top screen)
workspace "󰇧" { open-on-output "eDP-1"; }
workspace "󰭹" { open-on-output "eDP-1"; }
workspace "󰆍" { open-on-output "eDP-1"; }
workspace "󰈚" { open-on-output "eDP-1"; }
workspace "󰅴" { open-on-output "eDP-1"; }
workspace "󰄨" { open-on-output "eDP-1"; }
workspace "󰍉" { open-on-output "eDP-1"; }
workspace "󰧑" { open-on-output "eDP-1"; }
workspace "󰳪" { open-on-output "eDP-1"; }

// eDP-2 (bottom screen)
// Uses MDI variant icons to distinguish from eDP-1 while keeping same meanings.
// When eDP-2 is off (docked), these persist on eDP-1 at positions 10-18.
workspace "󰖟" { open-on-output "eDP-2"; }
workspace "󰍡" { open-on-output "eDP-2"; }
workspace "󰞷" { open-on-output "eDP-2"; }
workspace "󰧭" { open-on-output "eDP-2"; }
workspace "󰘦" { open-on-output "eDP-2"; }
workspace "󱁉" { open-on-output "eDP-2"; }
workspace "󱎸" { open-on-output "eDP-2"; }
workspace "󰠮" { open-on-output "eDP-2"; }
workspace "󰂓" { open-on-output "eDP-2"; }
EOF
    # First-time: new workspaces get prepended at index 0, need reorder
    niri msg action load-config-file 2>/dev/null || true
    sleep 0.3
    reorder_workspaces "${EDP1_WORKSPACES[@]}" "${EDP2_WORKSPACES[@]}"
}

generate_defaults

# Only run dock/undock logic on the Zenbook Duo
if [[ "$(hostname)" != "$ZENBOOK_HOSTNAME" ]]; then
    exit 0
fi

# One-time: create 18-workspace config with open-on-output constraints.
# Niri preserves workspace order across output on/off cycles natively,
# so we only need IPC reordering when workspaces are first created.
ensure_workspace_config

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

# Docked: disable eDP-2, workspaces auto-migrate to eDP-1 with order preserved.
# Niri's remove_output appends migrated workspaces in their existing order.
apply_docked() {
    niri msg output eDP-2 off
    write_nav_binds
}

# Undocked: enable eDP-2, workspaces with original_output="eDP-2" auto-migrate
# back with order preserved. Niri's add_output extracts matching workspaces.
apply_undocked() {
    write_nav_binds
    position_edp2_below
}

apply_dock_state() {
    if is_docked; then
        apply_docked
    else
        apply_undocked
    fi
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
