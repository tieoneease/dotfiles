#!/usr/bin/env bash

set -euo pipefail

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin)
            if [ "$(uname -m)" = "arm64" ]; then
                echo "macos-arm"
            else
                echo "macos-intel"
            fi
            ;;
        Linux)
            echo "linux"
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
    # Common packages for all platforms
    local common_packages=(
        "neovim"
        "tmux"
        "zsh"
        "stow"
        "tmux-sessionizer"
        "gh"
    )

    # Linux-specific packages
    local linux_packages=(
        "xclip"
        "libnotify"
        "grimblast"
    )

    # Install common packages
    for package in "${common_packages[@]}"; do
        echo "Installing $package..."
        nix-env -iA "nixpkgs.$package" || echo "Failed to install $package"
    done

    # Install OS-specific packages
    OS=$(detect_os)
    case "$OS" in
        linux)
            for package in "${linux_packages[@]}"; do
                echo "Installing $package..."
                nix-env -iA "nixpkgs.$package" || echo "Failed to install $package"
            done
            ;;
        macos-arm|macos-intel)
            echo "Skipping Linux-specific packages on macOS"
            ;;
        *)
            echo "Unknown OS, skipping OS-specific packages"
            ;;
    esac
}

# Function to install oh-my-zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        echo "oh-my-zsh is already installed"
    fi
}

# Function to install nvm and node packages
install_nvm() {
    if [ -d "$HOME/.nvm" ]; then
        echo "nvm is already installed"
    else
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # Load nvm in the current shell
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install LTS version of Node.js and set as default
    echo "Installing Node.js LTS..."
    nvm install --lts
    nvm alias default 'lts/*'

    # Install global npm packages
    echo "Installing global npm packages..."
    npm install -g typescript
}

# Function to install Nerd Fonts
install_fonts() {
    echo "Installing Nerd Fonts..."
    # Get the current directory
    local DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create fonts directory if it doesn't exist
    mkdir -p "$HOME/.local/share/fonts"
    
    FONTS_NIX="$DOTFILES_DIR/nix/config/fonts.nix"
    if [ -f "$FONTS_NIX" ]; then
        nix-env -f "$FONTS_NIX" -i
        echo "Nerd Fonts installed successfully"
    else
        echo "Error: fonts.nix not found at $FONTS_NIX"
        exit 1
    fi
}

# Function to setup fonts and font cache
setup_fonts() {
    echo "Setting up fonts..."
    
    # Install fontconfig if not already installed
    if ! command -v fc-cache >/dev/null 2>&1; then
        echo "Installing fontconfig..."
        nix-env -iA nixpkgs.fontconfig
    fi

    # Install fonts
    install_fonts

    # Get OS type
    OS=$(detect_os)

    # macOS-specific font setup
    if [[ "$OS" == "macos-arm" || "$OS" == "macos-intel" ]]; then
        echo "Setting up fonts for macOS..."
        
        # Ensure font directories exist
        mkdir -p "$HOME/Library/Fonts"

        # Link all Nix-managed fonts to macOS Font Book location
        echo "Linking Nix fonts to Font Book..."
        NIX_FONTS_DIR="$HOME/.nix-profile/share/fonts"
        
        # Function to create symlinks recursively
        link_fonts() {
            local src_dir="$1"
            find "$src_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0 | while IFS= read -r -d '' font; do
                local font_name=$(basename "$font")
                # Remove existing symlink if it exists
                rm -f "$HOME/Library/Fonts/$font_name"
                # Create new symlink
                ln -sf "$font" "$HOME/Library/Fonts/$font_name"
            done
        }

        # Link all fonts from Nix store
        if [ -d "$NIX_FONTS_DIR" ]; then
            echo "Linking fonts from $NIX_FONTS_DIR..."
            link_fonts "$NIX_FONTS_DIR"
        fi
    else
        # Linux font setup
        mkdir -p "$HOME/.local/share/fonts"
        mkdir -p "$HOME/.cache/fontconfig"
    fi

    # Update font cache
    echo "Updating font cache..."
    fc-cache -f -v

    # Verify fonts are installed
    echo "Verifying font installation..."
    fc-list | grep -i "InconsolataGo"
}

# Function to setup dotfiles using stow
setup_dotfiles() {
    # Create .config directory if it doesn't exist
    mkdir -p "$HOME/.config"

    # Create NVM directory if it doesn't exist
    mkdir -p "$HOME/.nvm"

    # Get the current directory
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$DOTFILES_DIR"

    # Handle zsh files separately
    echo "Setting up zsh configuration..."
    # Set up .zshenv for Nix
    ln -sf "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
    # Set up aliases
    ln -sf "$DOTFILES_DIR/zsh/.zsh_aliases" "$HOME/.zsh_aliases"
    # Set up .zshrc if it doesn't exist or backup if it does
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        echo "Backing up existing .zshrc to .zshrc.backup"
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    cp "$DOTFILES_DIR/zsh/zshrc.template" "$HOME/.zshrc"

    # Handle karabiner configuration
    KARABINER_CONFIG="$HOME/.config/karabiner/karabiner.json"
    if [ -f "$KARABINER_CONFIG" ] && [ ! -L "$KARABINER_CONFIG" ]; then
        echo "Backing up existing karabiner.json to karabiner.json.backup"
        mkdir -p "$HOME/.config/karabiner/backup"
        cp "$KARABINER_CONFIG" "$HOME/.config/karabiner/backup/karabiner.json.backup"
        rm "$KARABINER_CONFIG"
    fi

    # Check if Hyprland is running
    if pgrep -x "Hyprland" > /dev/null; then
        echo "Hyprland is running. Handling hyprland configs separately..."
        # Ensure hypr config directory exists
        mkdir -p "$HOME/.config/hypr"
        # Create symlink for hyprland config
        ln -sf "$DOTFILES_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
        # Create symlink for hyprpaper config
        ln -sf "$DOTFILES_DIR/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"
        # Stow everything except hypr and zsh directories
        stow --ignore=hypr --ignore=zsh .
    else
        # If Hyprland is not running, stow everything except zsh
        stow --ignore=zsh .
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

# Function to configure tmux-sessionizer
configure_tms() {
    echo "Configuring tmux-sessionizer..."
    
    # Create Workspace directory if it doesn't exist
    mkdir -p "$HOME/Workspace"
    
    # Configure tmux-sessionizer with default paths
    tms config --paths "$HOME/dotfiles" "$HOME/Workspace"
}

# Main function
main() {
    echo "Starting setup..."

    # Install Nix package manager
    install_nix

    # Install packages
    install_packages

    # Install Nerd Fonts
    # install_fonts

    # Install oh-my-zsh
    install_oh_my_zsh

    # Install nvm and node packages
    install_nvm

    # Setup fonts and font cache
    setup_fonts

    # Setup dotfiles using stow
    setup_dotfiles

    # Configure tmux-sessionizer
    configure_tms

    # Change default shell to Nix zsh
    change_shell

    echo "Setup completed successfully!"
}

main
