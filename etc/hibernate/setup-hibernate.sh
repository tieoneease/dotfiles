#!/usr/bin/env bash

set -euo pipefail

# Setup hibernate to swapfile
# Idempotent — safe to re-run (skips existing swap, updates offset if needed)

SWAPFILE="/swapfile"
CMDLINE="/etc/kernel/cmdline"

# --- Swap size (RAM rounded up to nearest GB) ---

mem_kb=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
mem_gb=$(( (mem_kb + 1048575) / 1048576 ))
swap_size="${mem_gb}G"
echo "RAM: ${mem_gb}G — swap size: ${swap_size}"

# --- Create swapfile ---

if [ -f "$SWAPFILE" ]; then
    echo "Swapfile already exists, skipping creation."
else
    echo "Creating ${swap_size} swapfile with dd..."
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((mem_gb * 1024)) status=progress
    chmod 0600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    echo "Swapfile created."
fi

# Activate swap if not already on
if ! swapon --show | grep -q "$SWAPFILE"; then
    swapon "$SWAPFILE"
    echo "Swap activated."
fi

# --- Add to fstab ---

if grep -q "$SWAPFILE" /etc/fstab; then
    echo "Swapfile already in fstab, skipping."
else
    echo "$SWAPFILE none swap defaults 0 0" >> /etc/fstab
    echo "Swapfile added to fstab."
fi

# --- Compute resume parameters ---

root_dev=$(findmnt -n -o SOURCE /)
root_uuid=$(blkid -s UUID -o value "$root_dev")
resume_offset=$(filefrag -v "$SWAPFILE" | awk '/^ *0:/ { gsub(/\./, "", $4); print $4 }')

echo "Root UUID: $root_uuid"
echo "Resume offset: $resume_offset"

# --- Update kernel cmdline ---

# Read current cmdline, strip any existing resume params
current=$(cat "$CMDLINE" 2>/dev/null || echo "")
updated=$(echo "$current" | sed -E 's/resume=[^ ]*//g; s/resume_offset=[^ ]*//g; s/  +/ /g; s/^ +| +$//g')

# Append resume params
updated="$updated resume=UUID=$root_uuid resume_offset=$resume_offset"
# Clean up whitespace
updated=$(echo "$updated" | sed 's/  */ /g; s/^ //; s/ $//')

if [ "$current" = "$updated" ]; then
    echo "Kernel cmdline already up to date."
else
    echo "$updated" > "$CMDLINE"
    echo "Updated $CMDLINE:"
    echo "  $updated"
fi

# --- Regenerate initramfs + boot entries ---

echo "Regenerating initramfs (dracut picks up resume= automatically)..."
reinstall-kernels

echo ""
echo "Hibernate setup complete. Reboot for changes to take effect."
echo "Verify after reboot:"
echo "  swapon --show"
echo "  cat /proc/cmdline"
echo "  systemctl hibernate"
