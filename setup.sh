#!/usr/bin/env bash

set -euo pipefail

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -q "arch" /etc/os-release; then
                echo "arch"
            elif grep -q "Ubuntu" /etc/os-release && grep -q "microsoft" /proc/version; then
                echo "wsl-ubuntu"
            else
                echo "unknown-linux"
            fi
            ;;
        Darwin*)
            if [[ $(uname -m) == 'arm64' ]]; then
                echo "macos-arm"
            else
                echo "macos-intel"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to install Nix
install_nix() {
    if command -v nix >/dev/null 2>&1; then
        echo "Nix is already installed"
        return
    fi

    OS=$(detect_os)
    case "$OS" in
        arch|wsl-ubuntu)
            curl -L https://nixos.org/nix/install | sh
            ;;
        macos-arm|macos-intel)
            curl -L https://nixos.org/nix/install | sh
            ;;
        *)
            echo "Unsupported operating system"
            exit 1
            ;;
    esac

    # Source nix
    if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
        . ~/.nix-profile/etc/profile.d/nix.sh
    fi
}

# Function to install packages using Nix
install_packages() {
    packages=(
        "neovim"
        "tmux"
        "zsh"
        "stow"
        "kitty"
    )

    for package in "${packages[@]}"; do
        echo "Installing $package..."
        nix-env -iA nixpkgs."$package"
    done
}

# Function to install oh-my-zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        echo "oh-my-zsh is already installed"
    fi
}

# Function to setup dotfiles using stow
setup_dotfiles() {
    # Create .config directory if it doesn't exist
    mkdir -p "$HOME/.config"

    # Get the current directory
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$DOTFILES_DIR"

    # Check if Hyprland is running
    if pgrep -x "Hyprland" > /dev/null; then
        echo "Hyprland is running. Handling hyprland.conf separately..."
        # Ensure hypr config directory exists
        mkdir -p "$HOME/.config/hypr"
        # Create symlink for hyprland config
        ln -sf "$DOTFILES_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
        # Stow everything except hypr directory
        stow --ignore=hypr .
    else
        # If Hyprland is not running, stow everything
        stow .
    fi
}

main() {
    echo "Starting setup..."
    
    # Install Nix
    install_nix
    
    # Install packages
    install_packages
    
    # Install oh-my-zsh
    install_oh_my_zsh
    
    # Setup dotfiles
    setup_dotfiles
    
    echo "Setup completed successfully!"
}

main
