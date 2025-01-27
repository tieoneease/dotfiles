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

# Function to check if package needs to be installed
needs_install() {
    local package="$1"
    local current_version
    current_version=$(nix-env -q "$package" 2>/dev/null)
    if [ -z "$current_version" ]; then
        return 0  # Package not installed
    fi
    
    # Get the version that would be installed
    local new_version
    new_version=$(nix-env -qA "nixpkgs.$package" 2>/dev/null)
    
    # Compare versions
    if [ "$current_version" != "$new_version" ]; then
        return 0  # Different version
    fi
    return 1  # Same version
}

# Function to install packages using Nix
install_packages() {
    packages=(
        "neovim"
        "tmux"
        "zsh"
        "stow"
        "kitty"
        "xclip"
        "libnotify"
    )

    for package in "${packages[@]}"; do
        if needs_install "$package"; then
            echo "Installing $package..."
            nix-env -iA nixpkgs."$package"
        else
            echo "Package $package is already at the latest version"
        fi
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

# Function to change default shell to Nix zsh
change_shell() {
    NIX_ZSH="$HOME/.nix-profile/bin/zsh"
    if [ "$SHELL" != "$NIX_ZSH" ]; then
        echo "Changing default shell to Nix zsh..."
        # Add Nix zsh to /etc/shells if it's not there
        if ! grep -q "$NIX_ZSH" /etc/shells; then
            echo "Adding Nix zsh to /etc/shells..."
            echo "$NIX_ZSH" | sudo tee -a /etc/shells
        fi
        # Change shell
        sudo chsh -s "$NIX_ZSH" "$USER"
    else
        echo "Shell is already Nix zsh"
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

    # Change default shell
    change_shell
    
    echo "Setup completed successfully!"
}

main
