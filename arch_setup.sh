#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Arch Linux configurations..."

# Check if running as root (which we don't want)
if [ "$EUID" -eq 0 ]; then
    echo "Please don't run this script as root"
    exit 1
fi

# Function to check and install packages
install_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "Installing packages: ${to_install[*]}"
        paru -S --needed --noconfirm "${to_install[@]}"
    fi
}

# Ensure paru is installed
if ! command -v paru &> /dev/null; then
    echo "Installing paru (AUR helper)..."
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd -
fi

# Install essential packages
echo "Installing essential packages..."
install_packages stow git zsh neovim tmux wget curl direnv fzf ripgrep fd unzip fontconfig dunst

# Install Window Manager and related packages
echo "Installing Hyprland and related packages..."
install_packages hyprland waybar wofi wl-clipboard xdg-desktop-portal-hyprland \
    qt5-wayland qt6-wayland polkit-kde-agent grim slurp swappy

# Install terminal emulator
echo "Installing kitty terminal..."
install_packages kitty

# Install font packages
echo "Installing fonts..."
install_packages ttf-hack-nerd ttf-jetbrains-mono-nerd ttf-fira-code-nerd \
    ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd

# Refresh font cache
echo "Refreshing font cache..."
fc-cache -f -v

# Install starship prompt
if ! command -v starship &> /dev/null; then
    echo "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh
fi

# Add zsh to shells
command -v zsh | sudo tee -a /etc/shells

# Change default shell to zsh
if [[ "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell to zsh..."
    # Use the standard location for zsh rather than relying on which
    sudo chsh -s /usr/bin/zsh $USER
fi

# Install tmux-sessionizer
echo "Installing tmux-sessionizer..."
mkdir -p ~/.local/bin
curl -o ~/.local/bin/tmux-sessionizer https://raw.githubusercontent.com/ThePrimeagen/tmux-sessionizer/master/tmux-sessionizer
chmod +x ~/.local/bin/tmux-sessionizer
if ! grep -q "tmux-sessionizer" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
fi

# Enable services
echo "Enabling necessary services..."
systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service

# Ensure SDDM is disabled since we're using ly
echo "Ensuring SDDM is disabled (using ly instead)..."
sudo systemctl disable sddm 2>/dev/null || true

# Run stow script to link dotfiles
echo "Running stow script to link dotfiles..."
chmod +x "$HOME/dotfiles/stow/stow_dotfiles.sh"
"$HOME/dotfiles/stow/stow_dotfiles.sh"

echo "Arch Linux setup completed! Please reboot your system for all changes to take effect."
echo "After reboot, you can log in with Hyprland through ly."
