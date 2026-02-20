#!/usr/bin/env bash
set -euo pipefail

# Toggle eDP-2 based on keyboard dock state
# USB ID 0b05:1b2c = ASUS Zenbook Duo 2024 Keyboard
# (2025 model uses 0b05:1bf2)

NIRI_CONFIG_DIR="$HOME/.config/niri"
DEVICE_CONFIG_DIR="$NIRI_CONFIG_DIR/devices"
ZENBOOK_HOSTNAME="sam-duomoon"

# Workspace icon arrays — single source of truth for intended ordering.
# Workspaces are declared in config so niri creates them, then
# reorder_workspaces() sets the correct positions via IPC after each reload.
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

# Generate single-monitor defaults if include files don't exist yet.
# Ensures non-Zenbook devices get valid include files on first boot.
# Icons must match EDP1_WORKSPACES to stay in sync.
generate_defaults() {
    if [[ ! -f "$NIRI_CONFIG_DIR/monitor-workspaces.kdl" ]]; then
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

# Write workspace declarations — always all 18 with open-on-output constraints.
# Single config for both docked and undocked modes. When eDP-2 is off, its
# workspaces live on eDP-1 but retain original_output="eDP-2", so they
# auto-migrate back when eDP-2 is enabled. No mode-specific branching needed.
write_workspace_config() {
    local f="$NIRI_CONFIG_DIR/monitor-workspaces.kdl"
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
}

# Docked: disable eDP-2 (workspaces auto-migrate to eDP-1 with original_output
# preserved), reload config, reorder all 18 workspaces on eDP-1
apply_docked() {
    niri msg output eDP-2 off
    write_workspace_config
    write_nav_binds
    niri msg action load-config-file 2>/dev/null || true
    sleep 0.1
    reorder_workspaces "${EDP1_WORKSPACES[@]}" "${EDP2_WORKSPACES[@]}"
}

# Undocked: reload config, enable eDP-2 (workspaces with original_output="eDP-2"
# auto-migrate back), reorder both monitors
apply_undocked() {
    write_workspace_config
    write_nav_binds
    niri msg action load-config-file 2>/dev/null || true
    sleep 0.1
    reorder_workspaces "${EDP1_WORKSPACES[@]}"
    position_edp2_below
    # Wait for workspaces to migrate to eDP-2 before reordering (bounded poll)
    local attempt
    for attempt in {1..20}; do
        local count
        count=$(niri msg -j workspaces | jq '[.[] | select(.output == "eDP-2")] | length')
        [[ "$count" -ge 9 ]] && break
        sleep 0.05
    done
    reorder_workspaces "${EDP2_WORKSPACES[@]}"
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
