#!/usr/bin/env bash

set -euo pipefail

# Patch Noctalia Shell QML system files by copying pre-patched versions.
# Called by arch_setup.sh after noctalia-shell-git is installed.
# Idempotent — skips files that already match.
# Requires root (files live under /etc/xdg/quickshell/).
#
# Usage:
#   sudo bash patch_noctalia.sh                    # Apply patched files
#   sudo bash patch_noctalia.sh --save-upstream-hashes  # Record current system file hashes

NOCTALIA_DIR="/etc/xdg/quickshell/noctalia-shell"
PATCHES_DIR="$(cd "$(dirname "$0")" && pwd)/patches/noctalia"
UPSTREAM_CHECKSUMS="$PATCHES_DIR/upstream.sha256"

# Maps patch filename → relative path under NOCTALIA_DIR
declare -A FILE_PATHS=(
    ["CalendarMonthCard.qml"]="Modules/Cards/CalendarMonthCard.qml"
    ["WeatherCard.qml"]="Modules/Cards/WeatherCard.qml"
    ["ClockPanel.qml"]="Modules/Panels/Clock/ClockPanel.qml"
    ["Tooltip.qml"]="Modules/Tooltip/Tooltip.qml"
    ["NIcon.qml"]="Widgets/NIcon.qml"
    ["Workspace.qml"]="Modules/Bar/Widgets/Workspace.qml"
)

# Record sha256 hashes of current system files (run on fresh upstream before patching)
save_upstream_hashes() {
    echo "Saving upstream Noctalia checksums..."
    local tmpfile
    tmpfile=$(mktemp)

    for name in "${!FILE_PATHS[@]}"; do
        local dst="$NOCTALIA_DIR/${FILE_PATHS[$name]}"
        if [ ! -f "$dst" ]; then
            echo "  ⚠ $name: system file not found at $dst — skipping"
            continue
        fi
        sha256sum "$dst" | sed "s|.*  |&|; s|$dst|$name|" >> "$tmpfile"
        echo "  ✓ $name"
    done

    mv "$tmpfile" "$UPSTREAM_CHECKSUMS"
    echo "Upstream checksums saved to $UPSTREAM_CHECKSUMS"
}

# Apply a single patched file
apply_patched_file() {
    local name="$1"
    local src="$PATCHES_DIR/$name"
    local dst="$NOCTALIA_DIR/${FILE_PATHS[$name]}"

    if [ ! -f "$src" ]; then
        echo "  ⚠ $name: patch file not found at $src"
        return 1
    fi

    if [ ! -f "$dst" ]; then
        echo "  ⚠ $name: system file not found at $dst"
        return 1
    fi

    local src_hash dst_hash
    src_hash=$(sha256sum "$src" | cut -d' ' -f1)
    dst_hash=$(sha256sum "$dst" | cut -d' ' -f1)

    # Already applied
    if [ "$src_hash" = "$dst_hash" ]; then
        echo "  ✓ $name (already applied)"
        return 0
    fi

    # Check if upstream changed since we last based our patches on it
    local expected_hash
    expected_hash=$(grep "  $name\$" "$UPSTREAM_CHECKSUMS" 2>/dev/null | cut -d' ' -f1 || true)
    if [ -n "$expected_hash" ] && [ "$dst_hash" != "$expected_hash" ] && [ "$dst_hash" != "$src_hash" ]; then
        echo "  ⚠ $name: upstream changed — review and update patches/noctalia/$name"
        echo "    Expected upstream: ${expected_hash:0:16}..."
        echo "    Current system:    ${dst_hash:0:16}..."
        echo "    Diff: diff $dst $src"
        return 1
    fi

    cp "$src" "$dst"
    echo "  ✓ $name (applied)"
    return 0
}

# Apply all patched files
apply_all() {
    echo "Patching Noctalia Shell QML files..."
    local failed=0

    for name in "${!FILE_PATHS[@]}"; do
        if ! apply_patched_file "$name"; then
            ((failed++))
        fi
    done

    if [ "$failed" -gt 0 ]; then
        echo "Noctalia patches: $failed file(s) need attention."
        return 1
    fi

    echo "Noctalia patches complete."
}

# --- Main ---

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: patch_noctalia.sh must be run as root"
    exit 1
fi

if [ ! -d "$NOCTALIA_DIR" ]; then
    echo "Error: Noctalia directory not found at $NOCTALIA_DIR"
    exit 1
fi

case "${1:-}" in
    --save-upstream-hashes)
        save_upstream_hashes
        ;;
    *)
        apply_all
        ;;
esac
