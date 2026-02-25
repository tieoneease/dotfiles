#!/usr/bin/env bash

set -euo pipefail

# Arch Linux setup script (EndeavourOS, CachyOS, etc.)
# Sets up Niri + Noctalia Shell desktop environment

if [ "$EUID" -eq 0 ]; then
    echo "Please don't run this script as root"
    exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Dotfiles directory: $DOTFILES_DIR"

# --- AUR helper detection ---

# Detect AUR helper (paru preferred, yay as fallback)
if command -v paru &> /dev/null; then
    AUR_HELPER=paru
elif command -v yay &> /dev/null; then
    AUR_HELPER=yay
else
    echo "Error: No AUR helper found. Install paru or yay first."
    exit 1
fi
echo "Using AUR helper: $AUR_HELPER"

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
        $AUR_HELPER -S --needed --noconfirm "${to_install[@]}"
    fi
}

# Remove CachyOS default zsh config (replaced by dotfiles zsh config)
if pacman -Qi cachyos-zsh-config &>/dev/null; then
    echo "Removing cachyos-zsh-config (replaced by dotfiles zsh config)..."
    sudo pacman -Rns --noconfirm cachyos-zsh-config || sudo pacman -Rd --noconfirm cachyos-zsh-config
fi

# Core CLI tools
echo "Installing core CLI tools..."
install_packages stow git zsh neovim tmux wget curl direnv fzf ripgrep fd unzip fontconfig starship jq pkgfile expac

# File manager
echo "Installing file manager..."
install_packages yazi imagemagick poppler ueberzugpp chafa

# Desktop environment
echo "Installing desktop environment..."
# niri — use custom build with per-device tablet/touch config on Zenbook Duo
if [[ "$(hostname)" == "sam-duomoon" ]]; then
    if ! pacman -Qi niri-git &> /dev/null; then
        echo "Building niri-git from PR #1856 fork (per-device tablet/touch config)..."
        pushd "$DOTFILES_DIR/niri-git"
        makepkg -si --noconfirm
        popd
    fi
    # Prevent AUR helper from overwriting the custom build
    if ! grep -q "IgnorePkg.*niri-git" /etc/pacman.conf; then
        sudo sed -i '/^\[options\]/a IgnorePkg = niri-git' /etc/pacman.conf
    fi
else
    install_packages niri-git
fi
install_packages noctalia-shell-git walker-bin elephant-all matugen-bin xwayland-satellite

# Greeter
echo "Installing greeter..."
install_packages greetd greetd-tuigreet

# Keyboard daemon
echo "Installing keyd..."
install_packages keyd

# Terminals
echo "Installing terminal emulators..."
install_packages kitty

# Desktop utilities
echo "Installing desktop utilities..."
install_packages swayidle playerctl network-manager-applet brightnessctl wl-clipboard bluez bluez-utils \
    xdg-desktop-portal xdg-desktop-portal-gtk wlsunset localsend-bin libinput-tools fuse2 xdg-utils

# Calendar sync (khal + vdirsyncer for Noctalia calendar events)
echo "Installing calendar sync tools..."
install_packages khal vdirsyncer python-aiohttp-oauthlib google-cloud-cli

# Input method framework (Chinese Traditional Pinyin)
echo "Installing input method framework..."
install_packages fcitx5 fcitx5-gtk fcitx5-qt fcitx5-rime fcitx5-configtool noto-fonts-cjk rime-ice-git

# Browser
# google-chrome: daily browsing; chromium: required by webapp-launch for Gemini/Perplexity shortcuts
echo "Installing browser..."
install_packages google-chrome chromium

# Editor
echo "Installing editor..."
install_packages visual-studio-code-bin

# Communication
echo "Installing communication tools..."
install_packages slack-desktop  # XWayland version for better stability
install_packages vesktop-bin

# Networking / VPN
echo "Installing networking tools..."
install_packages tailscale

# Productivity applications
echo "Installing productivity applications..."
install_packages obsidian zathura zathura-pdf-mupdf

# Pencil.dev design tool
echo "Installing Pencil.dev..."
PENCIL_DIR="$HOME/.local/share/pencil"
if [ ! -f "$PENCIL_DIR/Pencil.AppImage" ]; then
    mkdir -p "$PENCIL_DIR"
    curl -fSL -o "$PENCIL_DIR/Pencil.AppImage" \
        "https://5ykymftd1soethh5.public.blob.vercel-storage.com/Pencil-linux-x86_64.AppImage"
    chmod +x "$PENCIL_DIR/Pencil.AppImage"
fi

# Voice-to-text
echo "Installing voice-to-text tools..."
install_packages whisper.cpp dotool gtk4-layer-shell python-sounddevice python-numpy python-gobject

# Zsh plugins (system-wide, sourced from /usr/share/zsh/plugins/)
echo "Installing zsh plugins..."
install_packages zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search

# Fonts
echo "Installing fonts..."
install_packages ttf-hack-nerd ttf-jetbrains-mono-nerd ttf-firacode-nerd \
    ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd inter-font \
    ttf-inconsolata-go-nerd

# Update pkgfile database (for command-not-found suggestions)
if command -v pkgfile &>/dev/null; then
    echo "Updating pkgfile database..."
    sudo pkgfile -u
fi

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

# Copy udev rules (HID device access for VIA/Vial keyboard configurators)
echo "Configuring udev rules..."
sudo mkdir -p /etc/udev/rules.d
sudo cp -f "$DOTFILES_DIR/etc/udev/rules.d/50-qmk.rules" /etc/udev/rules.d/
sudo cp -f "$DOTFILES_DIR/etc/udev/rules.d/59-vial.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules

# Copy modules-load.d configs (uhid for BT keyboard/trackpad input)
echo "Configuring kernel modules..."
sudo mkdir -p /etc/modules-load.d
sudo cp -f "$DOTFILES_DIR/etc/modules-load.d/bluetooth.conf" /etc/modules-load.d/bluetooth.conf

# Patch Noctalia Shell QML files (workspace icons, calendar, weather, tooltips, NIcon)
echo "Patching Noctalia Shell QML files..."
sudo bash "$DOTFILES_DIR/patch_noctalia.sh"

# Copy portal config
echo "Configuring xdg-desktop-portal..."
sudo mkdir -p /etc/xdg-desktop-portal
sudo cp -f "$DOTFILES_DIR/etc/xdg-desktop-portal/portals.conf" /etc/xdg-desktop-portal/portals.conf

# Copy libinput quirks for Zenbook Duo (DWT fix for keyd + detachable keyboard touchpad)
if [[ "$(hostname)" == "sam-duomoon" ]]; then
    echo "Configuring libinput quirks for Zenbook Duo..."
    sudo mkdir -p /etc/libinput
    sudo cp -f "$DOTFILES_DIR/etc/libinput/local-overrides.quirks" /etc/libinput/local-overrides.quirks

    echo "Configuring udev hwdb for Zenbook Duo BT touchpad..."
    sudo mkdir -p /etc/udev/hwdb.d
    sudo cp -f "$DOTFILES_DIR/etc/udev/hwdb.d/71-touchpad-local.hwdb" /etc/udev/hwdb.d/

    echo "Suppressing phantom WMI media key events..."
    sudo cp -f "$DOTFILES_DIR/etc/udev/hwdb.d/72-asus-wmi-suppress.hwdb" /etc/udev/hwdb.d/

    sudo systemd-hwdb update
fi

# GPD Win Max 2 hardware setup (amdgpu stability, BMI260 IMU, HHD)
if [[ "$(hostname)" == "sam-ganymede" ]]; then
    echo "Installing GPD Win Max 2 packages..."
    # Ensure kernel headers are installed for DKMS modules
    KERNEL_PKG=$(pacman -Qqs '^linux-cachyos$' 2>/dev/null || pacman -Qqs '^linux$' 2>/dev/null || echo "linux")
    HEADERS_PKG="${KERNEL_PKG}-headers"
    install_packages "$HEADERS_PKG"
    install_packages bmi260-dkms hhd game-devices-udev

    echo "Configuring amdgpu for GPD Win Max 2..."
    sudo mkdir -p /etc/modprobe.d
    sudo cp -f "$DOTFILES_DIR/etc/modprobe.d/amdgpu.conf" /etc/modprobe.d/amdgpu.conf

    echo "Blacklisting bmi160 modules (BIOS misidentifies BMI260 as BMI160)..."
    sudo cp -f "$DOTFILES_DIR/etc/modprobe.d/blacklist-bmi160.conf" /etc/modprobe.d/blacklist-bmi160.conf

    echo "Installing amdgpu power-stable udev rule..."
    sudo mkdir -p /etc/udev/rules.d
    sudo cp -f "$DOTFILES_DIR/etc/udev/rules.d/99-amdgpu-power-stable.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules

    echo "Enabling Handheld Daemon (HHD)..."
    sudo systemctl enable hhd@"$USER"
fi

# Set environment variables (merge into existing /etc/environment, don't overwrite)
echo "Setting system environment variables..."
set_env_var() {
    local key="$1" value="$2"
    if grep -q "^${key}=" /etc/environment 2>/dev/null; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" /etc/environment
    else
        echo "${key}=${value}" | sudo tee -a /etc/environment > /dev/null
    fi
}
set_env_var EDITOR nvim
set_env_var BROWSER google-chrome-stable
set_env_var XMODIFIERS '@im=fcitx'

# Enable services
echo "Enabling system services..."
sudo systemctl enable --now keyd.service
sudo systemctl enable greetd.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now tailscaled.service
if tailscale status &> /dev/null; then
    sudo tailscale set --operator="$USER"
fi

echo "Enabling user services..."
systemctl --user enable noctalia.service
if command -v elephant &> /dev/null; then
    # elephant installs the binary/providers, then generates its user unit on demand.
    elephant service enable
    systemctl --user daemon-reload
    systemctl --user enable --now elephant.service
else
    echo "Error: elephant binary not found after package installation."
    echo "Expected package: elephant-all"
    exit 1
fi

# --- Shell setup ---

if [[ "$SHELL" != *"zsh"* ]]; then
    echo "Changing default shell to zsh..."
    command -v zsh | sudo tee -a /etc/shells
    sudo chsh -s /usr/bin/zsh "$USER"
fi

# Write ~/.zshrc loader (backup existing if present)
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    echo "Backing up existing ~/.zshrc..."
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi
echo "Writing ~/.zshrc loader..."
cat > "$HOME/.zshrc" << 'ZSHRC'
# Source base configuration (managed by dotfiles)
[[ -f ~/.config/zsh/base.zsh ]] && source ~/.config/zsh/base.zsh

# Machine-specific configuration and installer additions below
# (mise, conda, rustup, etc. can safely append here)
ZSHRC

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

# --- mise (version manager for node, python, etc.) ---

echo "Installing mise..."
install_packages mise

# --- Nix package manager (optional) ---

if ! command -v nix &> /dev/null; then
    read -rp "Install Nix package manager (for direnv flake support)? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing Nix via Determinate Systems installer..."
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
            | sh -s -- install --no-confirm
        if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi

        # Install nix-direnv (enables `use flake` / `use nix` in .envrc files)
        if [ ! -f "$HOME/.nix-profile/share/nix-direnv/direnvrc" ]; then
            echo "Installing nix-direnv..."
            nix profile install nixpkgs#nix-direnv
        fi
    fi
else
    # Nix already installed — ensure nix-direnv is present
    if [ ! -f "$HOME/.nix-profile/share/nix-direnv/direnvrc" ]; then
        echo "Installing nix-direnv..."
        nix profile install nixpkgs#nix-direnv
    fi
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

# Symlink Claude Code project memory to version-controlled files
ENCODED_PATH=$(echo "$DOTFILES_DIR" | sed 's|/|-|g')
MEMORY_LINK="$HOME/.claude/projects/${ENCODED_PATH}/memory"
mkdir -p "$HOME/.claude/projects/${ENCODED_PATH}"
if [ -d "$MEMORY_LINK" ] && [ ! -L "$MEMORY_LINK" ]; then
    rm -rf "$MEMORY_LINK"
fi
ln -sfn "$DOTFILES_DIR/claude-memory" "$MEMORY_LINK"

# --- Codex CLI ---

$AUR_HELPER -S --needed --noconfirm openai-codex

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

    # asusd restart drop-in (work around hidraw FD leak)
    echo "Configuring asusd restart drop-in..."
    sudo mkdir -p /etc/systemd/system/asusd.service.d
    sudo cp -f "$DOTFILES_DIR/etc/systemd/system/asusd.service.d/restart.conf" /etc/systemd/system/asusd.service.d/
    sudo systemctl daemon-reload

    echo "ASUS Zenbook Duo setup complete."
    echo "  - asusctl manages fn keys, keyboard backlight, and platform profiles"
    echo "  - wev can diagnose function key issues (run 'wev' and press keys)"
    echo "  - Dock/undock script auto-toggles eDP-2 on keyboard attach/detach"
fi

# --- Gaming ---

if pacman -Si cachyos-gaming-meta &>/dev/null; then
    echo ""
    echo "CachyOS detected — installing gaming meta-packages..."
    install_packages cachyos-gaming-meta cachyos-gaming-applications
    echo "Gaming setup complete (CachyOS meta-packages)."
else
    echo ""
    echo "Gaming setup: Steam, gamescope, MangoHud, gamemode, AMD Vulkan drivers, and Proton manager."
    read -rp "Install gaming tools? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing gaming tools..."
        install_packages steam gamescope mangohud lib32-mangohud gamemode lib32-gamemode \
            vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader \
            vulkan-mesa-layers lib32-vulkan-mesa-layers vulkan-tools \
            lib32-mesa lib32-systemd lib32-pipewire lib32-openal lib32-alsa-plugins \
            lib32-fontconfig lib32-gtk3 \
            lib32-gst-plugins-base lib32-gst-plugins-good lib32-gstreamer \
            libva lib32-libva ttf-liberation
        install_packages protonup-qt

        if ! groups "$USER" | grep -q gamemode; then
            sudo usermod -aG gamemode "$USER"
        fi

        echo "Gaming setup complete."
        echo "  - Steam launch option for games: gamescope -f -w 1920 -h 1080 -W 1920 -H 1080 --force-grab-cursor --backend sdl -- %command%"
        echo "  - Run protonup-qt to install GE-Proton for better game compatibility"
        echo "  - If Steam shows a black window: Settings → Interface → disable GPU accelerated rendering"
    fi
fi

# --- Stow dotfiles ---

echo "Running stow script..."
chmod +x "$DOTFILES_DIR/stow/stow_dotfiles.sh"
"$DOTFILES_DIR/stow/stow_dotfiles.sh"

# Enable services that depend on stow-deployed unit files
systemctl --user daemon-reload
systemctl --user enable --now dotoold.service
systemctl --user enable voice-recorder.service
systemctl --user enable walker.service
systemctl --user enable --now vdirsyncer.timer

# Install mise-managed tools (needs stow-deployed config)
if command -v mise &> /dev/null; then
    echo "Installing mise-managed tools (node LTS, etc.)..."
    mise install
fi

# Pi Coding Agent - install skills (web search, browser tools, etc.)
# Uses auto-discovery path (~/.pi/agent/skills/) not `pi install` — pi-skills
# repo lacks the package manifest structure that `pi install` expects.
PI_SKILLS_DIR="$HOME/.pi/agent/skills/pi-skills"
if command -v pi &> /dev/null; then
    if [[ ! -d "$PI_SKILLS_DIR" ]]; then
        echo "Installing Pi coding agent skills..."
        git clone https://github.com/badlogic/pi-skills "$PI_SKILLS_DIR"
    else
        echo "Updating Pi coding agent skills..."
        git -C "$PI_SKILLS_DIR" pull --ff-only
    fi
    # Install npm dependencies for skills that need them
    for dir in "$PI_SKILLS_DIR"/*/; do
        if [[ -f "$dir/package.json" && ! -d "$dir/node_modules" ]]; then
            echo "  npm install in $(basename "$dir")..."
            (cd "$dir" && npm install --silent)
        fi
    done
    # Disable unused skills (keep only brave-search + browser-tools)
    PI_SETTINGS="$HOME/.pi/agent/settings.json"
    if [[ -f "$PI_SETTINGS" ]] && ! grep -q '"skills"' "$PI_SETTINGS"; then
        echo "Disabling unused Pi skills (keeping brave-search, browser-tools)..."
        TMP_SETTINGS=$(mktemp)
        node -e "
            const s = JSON.parse(require('fs').readFileSync('$PI_SETTINGS', 'utf8'));
            s.skills = [
                '-pi-skills/gccli/SKILL.md',
                '-pi-skills/gdcli/SKILL.md',
                '-pi-skills/gmcli/SKILL.md',
                '-pi-skills/transcribe/SKILL.md',
                '-pi-skills/vscode/SKILL.md',
                '-pi-skills/youtube-transcript/SKILL.md'
            ];
            require('fs').writeFileSync('$TMP_SETTINGS', JSON.stringify(s, null, 2) + '\n');
        "
        mv "$TMP_SETTINGS" "$PI_SETTINGS"
    fi
else
    echo "⚠ Pi coding agent not found, skipping skills install"
fi

# Copy secrets template if no secrets file exists yet
SECRETS_FILE="$HOME/.config/secrets/env"
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "Creating secrets file from template..."
    mkdir -p "$(dirname "$SECRETS_FILE")"
    cp "$DOTFILES_DIR/secrets/env.example" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    echo "⚠ Fill in API keys at: $SECRETS_FILE"
fi

# Set GTK dark mode preference
echo "Setting system-wide dark mode preference..."
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    echo "✓ Set gsettings color-scheme to prefer-dark"
else
    echo "⚠ gsettings not found, skipping"
fi

# Set zathura as default PDF viewer
echo "Setting zathura as default PDF viewer..."
xdg-mime default org.pwmt.zathura.desktop application/pdf

# Sync default wallpapers (add new ones without overwriting existing)
echo "Syncing default wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$DOTFILES_DIR/wallpapers/"*.jpg "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
cp -n "$DOTFILES_DIR/wallpapers/"*.png "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

# --- Whisper model ---

WHISPER_MODEL_DIR="$HOME/.local/share/whisper-models"
if [ ! -f "$WHISPER_MODEL_DIR/ggml-base.en.bin" ]; then
    echo "Downloading whisper base.en model..."
    mkdir -p "$WHISPER_MODEL_DIR"
    curl -L -o "$WHISPER_MODEL_DIR/ggml-base.en.bin" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
fi

# --- Web apps ---

echo "Installing web apps..."
WEBAPP_ICONS="$HOME/.local/share/icons"

if [ ! -f "$WEBAPP_ICONS/webapp-gemini.png" ]; then
    echo "Installing Gemini web app..."
    ~/.local/bin/webapp-install "Gemini" "https://gemini.google.com/app" \
        "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Google_Gemini_logo.svg/1200px-Google_Gemini_logo.svg.png"
fi

if [ ! -f "$WEBAPP_ICONS/webapp-perplexity.png" ]; then
    echo "Installing Perplexity web app..."
    # Note: perplexity.ai/favicon.ico fails — magick can't decode ICO on this system.
    # apple-touch-icon.png (180×180 PNG) works reliably.
    ~/.local/bin/webapp-install "Perplexity" "https://www.perplexity.ai/" \
        "https://www.perplexity.ai/apple-touch-icon.png"
    ~/.local/bin/webapp-install "NotebookLM" "https://notebooklm.google.com/" \
        "https://www.gstatic.com/images/branding/product/2x/notebooklm_512dp.png"
fi

# --- Done ---

echo ""
echo "Setup complete!"
echo "  - Run 'sudo tailscale up' to authenticate with Tailscale (if not already connected)."
echo "  - Disable key expiry in the Tailscale admin console for machines that should stay connected."
echo "  - Run 'setup-google-calendar' to connect Google Calendar (one-time)."
echo "Reboot to start niri via greetd."
echo "If greetd fails, switch to TTY2 (Ctrl+Alt+F2) and run:"
echo "  sudo bash ~/dotfiles/rollback-greetd.sh"
