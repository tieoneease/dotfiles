#!/usr/bin/env bash

set -euo pipefail

# EndeavourOS / Arch Linux setup script
# Sets up Niri + Noctalia Shell desktop environment

if [ "$EUID" -eq 0 ]; then
    echo "Please don't run this script as root"
    exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Dotfiles directory: $DOTFILES_DIR"

# --- Package installation ---

install_packages() {
    local to_install=()
    for pkg in "$@"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "Installing: ${to_install[*]}"
        yay -S --needed --noconfirm "${to_install[@]}"
    fi
}

# Ensure yay is available (EndeavourOS ships it)
if ! command -v yay &> /dev/null; then
    echo "Error: yay not found. Install it first or use EndeavourOS."
    exit 1
fi

# Core CLI tools
echo "Installing core CLI tools..."
install_packages stow git zsh neovim tmux wget curl direnv fzf ripgrep fd unzip fontconfig starship jq

# File manager
echo "Installing file manager..."
install_packages yazi imagemagick poppler ueberzugpp chafa

# Desktop environment
echo "Installing desktop environment..."
install_packages niri noctalia-shell-git fuzzel matugen-bin

# Greeter
echo "Installing greeter..."
install_packages greetd greetd-tuigreet

# Keyboard daemon
echo "Installing keyd..."
install_packages keyd

# Terminals
echo "Installing terminal emulators..."
install_packages kitty alacritty

# Desktop utilities
echo "Installing desktop utilities..."
install_packages swayidle playerctl network-manager-applet brightnessctl wl-clipboard bluez bluez-utils \
    xdg-desktop-portal xdg-desktop-portal-gtk wlsunset

# Input method framework (Chinese Traditional Pinyin)
echo "Installing input method framework..."
install_packages fcitx5 fcitx5-gtk fcitx5-qt fcitx5-chinese-addons fcitx5-configtool noto-fonts-cjk

# Browser
echo "Installing browser..."
install_packages google-chrome

# Productivity applications
echo "Installing productivity applications..."
install_packages obsidian

# Zsh plugins (system-wide, sourced from /usr/share/zsh/plugins/)
echo "Installing zsh plugins..."
install_packages zsh-autosuggestions zsh-syntax-highlighting

# Fonts
echo "Installing fonts..."
install_packages ttf-hack-nerd ttf-jetbrains-mono-nerd ttf-fira-code-nerd \
    ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd inter-font \
    ttf-inconsolata-go-nerd

echo "Refreshing font cache..."
fc-cache -f -v

# --- System configuration ---

# Copy keyd config
echo "Configuring keyd..."
sudo mkdir -p /etc/keyd
sudo cp -f "$DOTFILES_DIR/etc/keyd/default.conf" /etc/keyd/default.conf

# Copy greetd config
echo "Configuring greetd..."
sudo mkdir -p /etc/greetd
sudo cp -f "$DOTFILES_DIR/etc/greetd/config.toml" /etc/greetd/config.toml

# Copy bluetooth config
echo "Configuring bluetooth..."
sudo mkdir -p /etc/bluetooth
sudo cp -f "$DOTFILES_DIR/etc/bluetooth/main.conf" /etc/bluetooth/main.conf

# Copy modules-load.d configs (uhid for BT keyboard/trackpad input)
echo "Configuring kernel modules..."
sudo mkdir -p /etc/modules-load.d
sudo cp -f "$DOTFILES_DIR/etc/modules-load.d/bluetooth.conf" /etc/modules-load.d/bluetooth.conf

# Copy portal config
echo "Configuring xdg-desktop-portal..."
sudo mkdir -p /etc/xdg-desktop-portal
sudo cp -f "$DOTFILES_DIR/etc/xdg-desktop-portal/portals.conf" /etc/xdg-desktop-portal/portals.conf

# Set environment variables
echo "Setting system environment variables..."
sudo tee /etc/environment > /dev/null << 'EOF'
EDITOR=nvim
BROWSER=google-chrome-stable
XMODIFIERS=@im=fcitx
EOF

# Enable services
echo "Enabling system services..."
sudo systemctl enable --now keyd.service
sudo systemctl enable greetd.service
sudo systemctl enable --now bluetooth.service

echo "Enabling user services..."
systemctl --user enable noctalia.service

# --- Shell setup ---

if [[ "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell to zsh..."
    command -v zsh | sudo tee -a /etc/shells
    sudo chsh -s /usr/bin/zsh "$USER"
fi

# Generate ~/.zshrc loader if it doesn't exist
if [ ! -f "$HOME/.zshrc" ]; then
    echo "Creating ~/.zshrc loader..."
    cat > "$HOME/.zshrc" << 'ZSHRC'
# Source base configuration (managed by dotfiles)
[[ -f ~/.config/zsh/base.zsh ]] && source ~/.config/zsh/base.zsh

# Machine-specific configuration and installer additions below
# (nvm, conda, rustup, etc. can safely append here)
ZSHRC
fi

# --- Git config ---

if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then
    echo ""
    echo "Git identity not configured."
    read -rp "Git user name: " git_name
    read -rp "Git email: " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    echo "Git identity set to $git_name <$git_email>"
fi

# --- Rust + cargo tools ---

if ! command -v rustup &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

if ! command -v tms &> /dev/null; then
    echo "Installing tmux-sessionizer..."
    export PATH="$HOME/.cargo/bin:$PATH"
    cargo install tmux-sessionizer
fi

# --- Claude Code ---

if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Passwordless sudo for Claude Code (it cannot handle interactive password prompts)
if [ ! -f "/etc/sudoers.d/$USER" ]; then
    echo ""
    echo "Claude Code requires passwordless sudo to run system commands."
    echo "This will create /etc/sudoers.d/$USER with NOPASSWD: ALL."
    read -rp "Enable passwordless sudo for $USER? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$USER" > /dev/null
        sudo chmod 0440 "/etc/sudoers.d/$USER"
        echo "Passwordless sudo enabled."
    else
        echo "Skipped. Claude Code may prompt for sudo password interactively."
    fi
fi

# --- Workspace directory ---

mkdir -p "$HOME/Workspace"

# --- ASUS Zenbook Duo setup (optional) ---

echo ""
echo "ASUS Zenbook Duo 2024 (UX8406MA) hardware setup."
echo "This installs asusctl, wev, and configures the dual-screen layout for niri."
read -rp "Enable ASUS Zenbook Duo setup? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Installing ASUS Zenbook Duo packages..."
    install_packages asusctl wev

    echo "ASUS Zenbook Duo setup complete."
    echo "  - asusctl manages fn keys, keyboard backlight, and platform profiles"
    echo "  - wev can diagnose function key issues (run 'wev' and press keys)"
    echo "  - Dock/undock script auto-toggles eDP-2 on keyboard attach/detach"
fi

# --- Stow dotfiles ---

echo "Running stow script..."
chmod +x "$DOTFILES_DIR/stow/stow_dotfiles.sh"
"$DOTFILES_DIR/stow/stow_dotfiles.sh"

# Set GTK dark mode preference
echo "Setting system-wide dark mode preference..."
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    echo "✓ Set gsettings color-scheme to prefer-dark"
else
    echo "⚠ gsettings not found, skipping"
fi

# Create placeholder for niri colors (generated by matugen on first wallpaper selection)
if [ ! -f "$HOME/.config/niri/colors.kdl" ]; then
    touch "$HOME/.config/niri/colors.kdl"
fi

# Sync default wallpapers (add new ones without overwriting existing)
echo "Syncing default wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$DOTFILES_DIR/wallpapers/"*.jpg "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
cp -n "$DOTFILES_DIR/wallpapers/"*.png "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

# --- Done ---

echo ""
echo "Setup complete! Reboot to start niri via greetd."
echo "If greetd fails, switch to TTY2 (Ctrl+Alt+F2) and run:"
echo "  sudo bash ~/dotfiles/rollback-greetd.sh"
