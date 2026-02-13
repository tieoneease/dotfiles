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

# Desktop environment
echo "Installing desktop environment..."
install_packages niri noctalia-shell-git fuzzel

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
install_packages swaylock playerctl network-manager-applet brightnessctl wl-clipboard

# Browser
echo "Installing browser..."
install_packages google-chrome

# Zsh plugins (system-wide, sourced from /usr/share/zsh/plugins/)
echo "Installing zsh plugins..."
install_packages zsh-autosuggestions zsh-syntax-highlighting

# Fonts
echo "Installing fonts..."
install_packages ttf-hack-nerd ttf-jetbrains-mono-nerd ttf-fira-code-nerd \
    ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd ttf-inter \
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

# Set environment variables
echo "Setting system environment variables..."
sudo tee /etc/environment > /dev/null << 'EOF'
EDITOR=nvim
BROWSER=google-chrome-stable
EOF

# Enable services
echo "Enabling system services..."
sudo systemctl enable --now keyd.service
sudo systemctl enable greetd.service

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

# --- Rust + cargo tools ---

if ! command -v rustup &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

if ! command -v tms &> /dev/null; then
    echo "Installing tmux-sessionizer..."
    cargo install tmux-sessionizer
fi

# --- Claude Code ---

if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Copying Claude Code config..."
mkdir -p "$HOME/.claude"
cp -f "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
cp -f "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline-command.sh"

# --- Stow dotfiles ---

echo "Running stow script..."
chmod +x "$DOTFILES_DIR/stow/stow_dotfiles.sh"
"$DOTFILES_DIR/stow/stow_dotfiles.sh"

# --- Done ---

echo ""
echo "Setup complete! Reboot to start niri via greetd."
echo "If greetd fails, switch to TTY2 (Ctrl+Alt+F2) and run:"
echo "  sudo bash ~/dotfiles/rollback-greetd.sh"
