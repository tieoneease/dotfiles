#!/usr/bin/env bash

set -euo pipefail

# Script to stow dotfiles per-package with target=$HOME
# Each package mirrors the home directory structure (e.g., nvim/.config/nvim/)

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Dotfiles directory: $DOTFILES_DIR"

# Packages to stow (platform-independent)
PACKAGES=(nvim kitty tmux tms zsh starship fontconfig direnv nix niri noctalia claude gtk fcitx5 yazi webapps voice walker zathura pencil mise vdirsyncer wireplumber pipewire ssh)

# macOS-only packages
MACOS_PACKAGES=(aerospace sketchybar karabiner)

# VPS-only packages (headless server — no desktop apps)
VPS_PACKAGES=(zsh tmux tms starship direnv mise nvim claude ssh)

# Parse flags
VPS_MODE=false
for arg in "$@"; do
    case "$arg" in
        --vps) VPS_MODE=true ;;
    esac
done

# Determine platform and select packages
OS="$(uname -s)"

if $VPS_MODE; then
    PACKAGES=("${VPS_PACKAGES[@]}")
elif [[ "$OS" == "Darwin" ]]; then
    PACKAGES+=("${MACOS_PACKAGES[@]}")
fi

# Backup existing non-symlinked configs before stowing
backup_existing_files() {
    echo "Checking for existing configurations to back up..."

    local backed_up=false

    for pkg in "${PACKAGES[@]}"; do
        local config_dir="${HOME}/.config/${pkg}"
        if [ -d "$config_dir" ] && [ ! -L "$config_dir" ]; then
            mkdir -p "$BACKUP_DIR"
            echo "Backing up $pkg configuration..."
            cp -r "$config_dir" "$BACKUP_DIR/"
            rm -rf "$config_dir"
            backed_up=true
        fi
    done

    if $backed_up; then
        echo "Backup completed at $BACKUP_DIR"
    else
        echo "No existing configs to back up."
    fi
}

# Stow each package individually
stow_packages() {
    echo "Stowing dotfiles..."
    cd "$DOTFILES_DIR"

    for pkg in "${PACKAGES[@]}"; do
        if [ -d "$pkg" ]; then
            echo "  Stowing $pkg..."
            stow --restow "$pkg"
        else
            echo "  Skipping $pkg (directory not found)"
        fi
    done

    echo "All packages stowed."
}

# Install tmux plugins (TPM)
setup_tmux_plugins() {
    echo "Setting up tmux plugins..."
    local tmux_plugin_dir="${HOME}/.config/tmux/plugins"
    mkdir -p "$tmux_plugin_dir"

    if [ ! -f "$tmux_plugin_dir/tpm/tpm" ]; then
        echo "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$tmux_plugin_dir/tpm"
    fi

    # Remove legacy ~/.tmux.conf symlink if it exists
    if [ -L "$HOME/.tmux.conf" ]; then
        echo "Removing legacy tmux.conf symlink..."
        rm -f "$HOME/.tmux.conf"
    fi
}

# Backup top-level dotfiles that stow packages may conflict with
backup_toplevel_dotfiles() {
    local toplevel_files=(".zshenv")
    for f in "${toplevel_files[@]}"; do
        if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
            mkdir -p "$BACKUP_DIR"
            echo "Backing up ~/$f..."
            mv "$HOME/$f" "$BACKUP_DIR/$f"
        fi
    done
}

# Copy Noctalia .default configs to live paths if they don't already exist
# Noctalia reads settings.json/colors.json at runtime and writes to them on every
# UI toggle, so we track .default variants and let the live files stay untracked.
setup_noctalia_defaults() {
    local noctalia_dir="$HOME/.config/noctalia"
    for f in settings colors; do
        if [ -f "$noctalia_dir/${f}.default.json" ] && [ ! -e "$noctalia_dir/${f}.json" ]; then
            echo "  Copying ${f}.default.json → ${f}.json"
            cp "$noctalia_dir/${f}.default.json" "$noctalia_dir/${f}.json"
        fi
    done
}

setup_niri_includes() {
    local niri_dir="$HOME/.config/niri"
    local devices_dir="$niri_dir/devices"

    # Generate device-outputs.kdl from hostname-matched template
    if [ ! -e "$niri_dir/device-outputs.kdl" ] && [ -f "$devices_dir/$(hostname).kdl" ]; then
        echo "  Copying device output config for $(hostname)"
        cp "$devices_dir/$(hostname).kdl" "$niri_dir/device-outputs.kdl"
    fi

    # Copy device-specific input config (hostname-matched)
    local inputs_file="$devices_dir/$(hostname)-inputs.kdl"
    if [ -f "$inputs_file" ]; then
        echo "  Copying device input config for $(hostname)"
        cp "$inputs_file" "$niri_dir/device-inputs.kdl"
    fi

    # Create stub noctalia.kdl if Noctalia hasn't generated it yet
    # (empty file is valid KDL; static fallback colors in config.kdl apply)
    if [ ! -e "$niri_dir/noctalia.kdl" ]; then
        echo "  Creating stub noctalia.kdl (Noctalia will overwrite on first wallpaper change)"
        touch "$niri_dir/noctalia.kdl"
    fi

    # Create default workspace/nav configs if zenbook-duo-dock.sh hasn't run yet
    if [ ! -e "$niri_dir/monitor-workspaces.kdl" ]; then
        echo "  Creating default monitor-workspaces.kdl"
        cat > "$niri_dir/monitor-workspaces.kdl" << 'NIRI'
workspace "󰇧"
workspace "󰭹"
workspace "󰆍"
workspace "󰈚"
workspace "󰅴"
workspace "󰄨"
workspace "󰍉"
workspace "󰧑"
workspace "󰳪"
NIRI
    fi

    if [ ! -e "$niri_dir/monitor-nav.kdl" ]; then
        echo "  Creating default monitor-nav.kdl"
        printf 'binds {\n    Alt+J { focus-window-or-workspace-down; }\n    Alt+K { focus-window-or-workspace-up; }\n}\n' > "$niri_dir/monitor-nav.kdl"
    fi
}

main() {
    echo "Starting dotfiles setup..."

    BACKUP_DIR="${HOME}/.config_backup/$(date +%Y%m%d_%H%M%S)"
    backup_existing_files
    backup_toplevel_dotfiles
    stow_packages
    setup_tmux_plugins

    if ! $VPS_MODE; then
        setup_noctalia_defaults
        setup_niri_includes
    fi

    echo ""
    echo "Dotfiles setup completed successfully!"
    echo "To apply zsh changes, restart your terminal or run: source ~/.config/zsh/base.zsh"
}

main
