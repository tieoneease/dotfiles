#!/usr/bin/env bash

set -euo pipefail

# Script to properly stow dotfiles
# This handles the appropriate stow structure and manages conflicts

# Get the dotfiles directory (parent of this script)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Dotfiles directory: $DOTFILES_DIR"

# Target directory (default: ~/.config)
TARGET_DIR="${HOME}/.config"
echo "Target directory: $TARGET_DIR"

# Function to backup existing files before stowing
backup_existing_files() {
    echo "Backing up existing configurations..."
    
    # Create backup directory
    BACKUP_DIR="${HOME}/.config_backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Check for sketchybar and back it up if it exists
    if [ -d "${TARGET_DIR}/sketchybar" ] && [ ! -L "${TARGET_DIR}/sketchybar" ]; then
        echo "Backing up sketchybar configuration..."
        cp -r "${TARGET_DIR}/sketchybar" "$BACKUP_DIR/"
        rm -rf "${TARGET_DIR}/sketchybar"
    fi
    
    # Check for other common config directories that might exist
    for dir in nvim kitty hypr waybar tms tmux gtk-3.0 gtk-4.0 qt5ct qt6ct xremap wofi nix; do
        if [ -d "${TARGET_DIR}/$dir" ] && [ ! -L "${TARGET_DIR}/$dir" ]; then
            echo "Backing up $dir configuration..."
            cp -r "${TARGET_DIR}/$dir" "$BACKUP_DIR/"
            rm -rf "${TARGET_DIR}/$dir"
        fi
    done

    # Clean up old nested nix structure if it exists
    if [ -d "${TARGET_DIR}/nix/nix" ]; then
        echo "Cleaning up old nested nix structure..."
        rm -rf "${TARGET_DIR}/nix"
    fi
    
    # Check for legacy tmux config in home directory
    if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
        echo "Backing up legacy tmux configuration from home directory..."
        cp "$HOME/.tmux.conf" "$BACKUP_DIR/"
        rm -f "$HOME/.tmux.conf"
    fi
    
    echo "Backup completed at $BACKUP_DIR"
}

# Function to handle zsh configuration
setup_zsh() {
    echo "Setting up zsh configuration..."
    
    # Set up .zshenv for Nix
    ln -sf "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
    
    # Set up aliases if exists
    if [ -f "$DOTFILES_DIR/zsh/.zsh_aliases" ]; then
        ln -sf "$DOTFILES_DIR/zsh/.zsh_aliases" "$HOME/.zsh_aliases"
    fi
    
    # Set up .zshrc if it doesn't exist or backup if it does
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        echo "Backing up existing .zshrc to .zshrc.backup"
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    
    # Check if zshrc.template exists, otherwise use the update we made
    if [ -f "$DOTFILES_DIR/zsh/zshrc.template" ]; then
        cp "$DOTFILES_DIR/zsh/zshrc.template" "$HOME/.zshrc"
    else
        echo "Warning: zshrc.template not found. Your .zshrc might need manual updating."
    fi
}

# Function to unstow existing files
unstow_if_needed() {
    echo "Checking for existing stowed files..."
    
    # Check if directory is already stowed
    if [ -L "${TARGET_DIR}/nvim" ] || [ -L "${TARGET_DIR}/sketchybar" ]; then
        echo "Unstowing existing files..."
        cd "$DOTFILES_DIR" && stow --target="$TARGET_DIR" --delete --verbose --ignore=zsh --ignore=nix-derivations --ignore=stow --ignore=.DS_Store .
    fi
}

# Function to stow dotfiles
stow_dotfiles() {
    echo "Stowing dotfiles..."
    
    # Ensure target directory exists
    mkdir -p "$TARGET_DIR"
    
    # Change to dotfiles directory
    cd "$DOTFILES_DIR"
    
    # Stow everything except zsh directory, nix-derivations, stow scripts, and .DS_Store files
    stow --target="$TARGET_DIR" --verbose --ignore=zsh --ignore=nix-derivations --ignore=stow --ignore=.DS_Store .
    
    # No need to create a symbolic link since tmux 3.2+ natively supports XDG paths
    # Remove any existing legacy symlink if it exists
    if [ -L "$HOME/.tmux.conf" ]; then
        echo "Removing legacy tmux.conf symlink..."
        rm -f "$HOME/.tmux.conf"
    fi
    
    # Ensure tmux plugins are properly installed
    echo "Setting up tmux plugins..."
    mkdir -p "$TARGET_DIR/tmux/plugins"
    if [ ! -d "$TARGET_DIR/tmux/plugins/tpm" ]; then
        echo "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$TARGET_DIR/tmux/plugins/tpm"
    fi
    if [ ! -d "$TARGET_DIR/tmux/plugins/catppuccin" ]; then
        echo "Installing Catppuccin theme..."
        git clone https://github.com/catppuccin/tmux.git "$TARGET_DIR/tmux/plugins/catppuccin"
    fi
    
    echo "Dotfiles stowed successfully!"
}

# Main function
main() {
    echo "Starting dotfiles setup..."
    
    # Backup existing files
    backup_existing_files
    
    # Unstow if needed
    unstow_if_needed
    
    # Stow dotfiles
    stow_dotfiles
    
    # Setup zsh
    setup_zsh
    
    echo "Dotfiles setup completed successfully!"
    echo ""
    echo "To apply the changes to your zsh configuration, please restart your terminal or run:"
    echo "source ~/.zshrc"
}

# Execute main function
main