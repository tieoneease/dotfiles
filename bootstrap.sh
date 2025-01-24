#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting environment setup...${NC}"

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ -f "/etc/debian_version" ]]; then
    OS="debian"
elif [[ -f "/etc/fedora-release" ]]; then
    OS="fedora"
elif [[ -f "/etc/arch-release" ]]; then
    OS="arch"
else
    echo -e "${GREEN}Linux distribution detected. Using generic Linux installation method.${NC}"
    OS="linux"
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run this script as root${NC}"
    exit 1
fi

# Check if Nix is installed
if ! command -v nix &> /dev/null; then
    echo -e "${GREEN}Installing Nix...${NC}"
    
    if [[ "$OS" == "macos" ]]; then
        # macOS-specific installation
        sh <(curl -L https://nixos.org/nix/install) --darwin-use-unencrypted-nix-store-volume
    elif [[ "$OS" == "debian" || "$OS" == "fedora" || "$OS" == "arch" || "$OS" == "linux" ]]; then
        # Linux installation
        # Check if systemd is running
        if pidof systemd &> /dev/null; then
            # Multi-user installation for systemd systems
            sh <(curl -L https://nixos.org/nix/install) --daemon
        else
            # Single-user installation for non-systemd systems
            sh <(curl -L https://nixos.org/nix/install) --no-daemon
        fi
    else
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Waiting for Nix installation to complete...${NC}"
    sleep 5  # Give some time for the installation to finish
fi

# Source nix
if [[ "$OS" == "macos" ]]; then
    # macOS specific paths
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
else
    # Linux paths
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi

# Verify Nix is in PATH
if ! command -v nix &> /dev/null; then
    echo -e "${RED}Nix installation appears to have failed. Please restart your shell and try again.${NC}"
    exit 1
fi

# Install stow using Nix
echo -e "${GREEN}Installing stow...${NC}"
nix-env -iA nixpkgs.stow

# Install home-manager
echo -e "${GREEN}Installing home-manager...${NC}"

# Determine if we're using flakes
if grep -q "flake" ~/.config/home-manager/flake.nix 2>/dev/null; then
    echo -e "${GREEN}Detected flakes configuration. Installing home-manager with flakes support...${NC}"
    nix-channel --add https://nixos.org/nixpkgs/nixos-unstable nixpkgs
    nix-channel --update
    
    # Install home-manager using flakes
    nix-shell -p nixFlakes --run "nix run home-manager/master -- init --switch"
else
    echo -e "${GREEN}Installing home-manager using channels...${NC}"
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
    
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    nix-shell '<home-manager>' -A install
fi

# Create .config directory if it doesn't exist
mkdir -p ~/.config

# Clean up any existing symlinks
echo -e "${GREEN}Cleaning up existing configuration...${NC}"
rm -rf ~/.config/nix ~/.config/home-manager

# Use stow to create symlinks
echo -e "${GREEN}Setting up configuration files with stow...${NC}"
cd "$(dirname "$0")"

# Stow all directories that contain a .config subdirectory
for dir in */; do
    if [ -d "${dir}.config" ]; then
        echo -e "${GREEN}Stowing ${dir%/}...${NC}"
        stow -v -t ~ "${dir%/}"
    fi
done

echo -e "${GREEN}Running Nix setup script...${NC}"
./nix/setup.sh

# Set up zsh as default shell if it isn't already
NIXZSH="$(which zsh)"
if [[ "$SHELL" != "$NIXZSH" ]]; then
    echo -e "${GREEN}Setting up Nix-managed zsh as default shell...${NC}"
    if ! grep -q "$NIXZSH" /etc/shells; then
        echo -e "${GREEN}Adding Nix-managed zsh to valid login shells...${NC}"
        echo "You may be prompted for sudo password to add zsh to /etc/shells"
        sudo sh -c "echo $NIXZSH >> /etc/shells"
    fi
    
    echo -e "${GREEN}To change your default shell to zsh, run one of these commands:${NC}"
    echo "  chsh -s $NIXZSH"
    echo "  # or if that fails:"
    echo "  sudo usermod -s $NIXZSH $USER"
else
    echo -e "${GREEN}Zsh is already your default shell.${NC}"
fi

echo -e "${GREEN}Setup complete! Please log out and log back in for all changes to take effect.${NC}"
echo -e "${GREEN}After logging back in:${NC}"
echo -e "  - You'll be in zsh by default (if you changed your shell)"
echo -e "  - Home Manager's configuration will be loaded automatically"
echo -e "  - All your configured tools (starship, tmux, etc.) will be available"
