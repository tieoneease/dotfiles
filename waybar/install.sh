#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Waybar configuration...${NC}"

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}Error: This script is intended for Arch Linux only${NC}"
    exit 1
fi

# Function to install AUR package using yay
install_aur_package() {
    if ! command -v yay &> /dev/null; then
        echo -e "${RED}Error: yay is not installed. Please install yay first.${NC}"
        exit 1
    fi
    
    if ! yay -Q $1 &> /dev/null; then
        echo -e "${BLUE}Installing $1...${NC}"
        yay -S --noconfirm $1
    else
        echo -e "${GREEN}$1 is already installed${NC}"
    fi
}

# Install required packages
echo -e "${BLUE}Installing required packages...${NC}"
sudo pacman -S --needed --noconfirm waybar ttf-jetbrains-mono-nerd pavucontrol networkmanager

# Install AUR packages
echo -e "${BLUE}Installing AUR packages...${NC}"
install_aur_package networkmanager-dmenu-git

# Verify installations
echo -e "${BLUE}Verifying installations...${NC}"

# Check Waybar
if command -v waybar &> /dev/null; then
    echo -e "${GREEN}Waybar installed successfully${NC}"
else
    echo -e "${RED}Error: Waybar installation failed${NC}"
    exit 1
fi

# Check font installation
if fc-list | grep -q "JetBrains"; then
    echo -e "${GREEN}JetBrains Mono Nerd Font installed successfully${NC}"
else
    echo -e "${RED}Warning: JetBrains Mono Nerd Font might not be installed correctly${NC}"
fi

# Make sure Waybar autostart is in Hyprland config
if ! grep -q "^exec-once = waybar" ~/dotfiles/hypr/hyprland.conf; then
    echo -e "${BLUE}Adding Waybar to Hyprland autostart...${NC}"
    echo "exec-once = waybar" >> ~/dotfiles/hypr/hyprland.conf
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}Please restart Hyprland to apply changes.${NC}"
