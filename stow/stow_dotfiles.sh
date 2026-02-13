#!/usr/bin/env bash

set -euo pipefail

# Script to stow dotfiles per-package with target=$HOME
# Each package mirrors the home directory structure (e.g., nvim/.config/nvim/)

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Dotfiles directory: $DOTFILES_DIR"

# Packages to stow (platform-independent)
PACKAGES=(nvim kitty alacritty tmux tms zsh starship fontconfig direnv nix niri noctalia)

# macOS-only packages
MACOS_PACKAGES=(aerospace sketchybar karabiner)

# Determine platform
OS="$(uname -s)"

# Add platform-specific packages
if [[ "$OS" == "Darwin" ]]; then
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

    if [ ! -d "$tmux_plugin_dir/tpm" ]; then
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

main() {
    echo "Starting dotfiles setup..."

    BACKUP_DIR="${HOME}/.config_backup/$(date +%Y%m%d_%H%M%S)"
    backup_existing_files
    backup_toplevel_dotfiles
    stow_packages
    setup_tmux_plugins

    echo ""
    echo "Dotfiles setup completed successfully!"
    echo "To apply zsh changes, restart your terminal or run: source ~/.config/zsh/base.zsh"
}

main
