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

# Configure sudoers for paru to use pacman without password
echo "Configuring sudoers for passwordless pacman..."
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" | sudo tee /etc/sudoers.d/99-paru-pacman > /dev/null
sudo chmod 440 /etc/sudoers.d/99-paru-pacman

# Install essential packages
echo "Installing essential packages..."
install_packages stow git zsh neovim tmux wget curl direnv fzf ripgrep fd unzip fontconfig dunst

# Install network management tools
echo "Installing network management tools..."
install_packages networkmanager network-manager-applet

# Install xremap for keyboard remapping
echo "Installing xremap for keyboard remapping..."
install_packages xremap-hypr-bin

# Install Window Manager and related packages
echo "Installing Hyprland and related packages..."
install_packages hyprland waybar wofi wl-clipboard xdg-desktop-portal-hyprland \
    qt5-wayland qt6-wayland polkit-kde-agent grim slurp swappy hyprpaper brightnessctl

# Install terminal emulator
echo "Installing kitty terminal..."
install_packages kitty

# Install font packages
echo "Installing fonts..."
install_packages ttf-hack-nerd ttf-jetbrains-mono-nerd ttf-fira-code-nerd \
    ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd ttf-inter

# Install dark mode theme packages
echo "Installing dark mode theme packages..."
install_packages adwaita-icon-theme gnome-themes-extra qt5ct qt6ct \
    qt5-styleplugins qt6-styleplugins adwaita-qt5 adwaita-qt6 kvantum

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

# Install PipeWire and sound packages
echo "Installing and configuring PipeWire for sound..."
install_packages pipewire pipewire-pulse wireplumber pipewire-alsa sof-firmware

# Configure backlight permissions
echo "Configuring backlight permissions for ThinkPad..."
sudo tee /etc/udev/rules.d/90-backlight.rules &>/dev/null <<EOF
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

# Add user to video and input groups
echo "Adding user to video group for brightness control..."
sudo usermod -aG video $USER

# Add user to input group for xremap
echo "Adding user to input group for xremap..."
sudo usermod -aG input $USER
sudo gpasswd -a $USER input

# Configure uinput permissions for xremap
echo "Configuring uinput permissions for xremap..."
echo 'KERNEL=="uinput", GROUP="input", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-input.rules > /dev/null

# Configure uinput kernel module to load at boot
echo "Configuring uinput kernel module to load at boot..."
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf > /dev/null

# Load uinput module immediately
echo "Loading uinput kernel module..."
sudo modprobe uinput

# Reload udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload
sudo udevadm trigger

# Enable services
echo "Enabling necessary services..."
systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service

# Enable NetworkManager
echo "Enabling NetworkManager service..."
sudo systemctl enable --now NetworkManager.service

# Ensure SDDM is disabled since we're using ly
echo "Ensuring SDDM is disabled (using ly instead)..."
sudo systemctl disable sddm 2>/dev/null || true

# Apply Arch-specific configurations
echo "Applying Arch-specific configurations..."
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"
cp -f "$HOME/dotfiles/arch/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/"
cp -f "$HOME/dotfiles/arch/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/"
cp -f "$HOME/dotfiles/arch/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/"
cp -f "$HOME/dotfiles/arch/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/"
cp -f "$HOME/dotfiles/arch/hyprland-dark-mode.conf" "$HOME/.config/hypr/"
mkdir -p "$HOME/.local/bin"
cp -f "$HOME/dotfiles/arch/scripts/toggle_dark_mode.sh" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/toggle_dark_mode.sh"

# Run stow script to link dotfiles
echo "Running stow script to link dotfiles..."
chmod +x "$HOME/dotfiles/stow/stow_dotfiles.sh"
"$HOME/dotfiles/stow/stow_dotfiles.sh"

echo "Arch Linux setup completed! Please reboot your system for all changes to take effect."
echo "After reboot, you can log in with Hyprland through ly."
