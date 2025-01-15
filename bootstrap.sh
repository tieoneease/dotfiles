#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting environment setup...${NC}"

# Check if Nix is installed
if ! command -v nix &> /dev/null; then
    echo -e "${GREEN}Installing Nix...${NC}"
    curl -L https://nixos.org/nix/install | sh
    
    echo -e "${GREEN}Waiting for Nix installation to complete...${NC}"
    sleep 5  # Give some time for the installation to finish
    
    # Try multiple profile locations
    if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
        . ~/.nix-profile/etc/profile.d/nix.sh
    elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    else
        echo -e "${RED}Could not find Nix profile script. Please restart your shell and run this script again.${NC}"
        exit 1
    fi
fi

# Source nix if we haven't already
if [[ -z "${NIX_PATH}" ]]; then
    if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
        . ~/.nix-profile/etc/profile.d/nix.sh
    elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
fi

# Install stow using Nix
echo -e "${GREEN}Installing stow...${NC}"
nix-env -iA nixpkgs.stow

# Create .config directory if it doesn't exist
mkdir -p ~/.config

# Clean up any existing symlinks
echo -e "${GREEN}Cleaning up existing configuration...${NC}"
rm -rf ~/.config/nix ~/.config/home-manager

# Use stow to create symlinks
echo -e "${GREEN}Setting up configuration files with stow...${NC}"
cd "$(dirname "$0")"
stow -v --no-folding nix -t ~

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
