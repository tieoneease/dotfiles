#!/usr/bin/env bash

# Shared setup functions used by arch_setup.sh, vps_setup.sh, and macos_setup.sh
# Source this file after setting DOTFILES_DIR.

# --- Guards ---

ensure_not_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "Please don't run this script as root"
        exit 1
    fi
}

# --- Environment ---

# Upsert a KEY=VALUE pair in /etc/environment
set_env_var() {
    local key="$1" value="$2"
    if grep -q "^${key}=" /etc/environment 2>/dev/null; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" /etc/environment
    else
        echo "${key}=${value}" | sudo tee -a /etc/environment > /dev/null
    fi
}

# --- Rust + cargo tools ---

install_rust_and_cargo() {
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
}

# --- Claude Code ---

install_claude_code() {
    if ! command -v claude &> /dev/null; then
        echo "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
    fi
}

# --- Shell setup ---

setup_zsh_default_shell() {
    if [[ "$SHELL" != *"zsh"* ]]; then
        echo "Changing default shell to zsh..."
        command -v zsh | sudo tee -a /etc/shells
        sudo chsh -s /usr/bin/zsh "$USER"
    fi
}

# Write ~/.zshrc loader (idempotent — skips if loader is already present)
create_zshrc_loader() {
    local marker="# Source base configuration (managed by dotfiles)"

    if [ -f "$HOME/.zshrc" ] && grep -qF "$marker" "$HOME/.zshrc"; then
        echo "~/.zshrc loader already present, skipping."
        return
    fi

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
}

# --- Git config ---

configure_git_identity() {
    if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then
        echo ""
        echo "Git identity not configured."
        read -rp "Git user name: " git_name
        read -rp "Git email: " git_email
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo "Git identity set to $git_name <$git_email>"
    fi
}

# --- mise ---

run_mise_install() {
    if command -v mise &> /dev/null; then
        echo "Installing mise-managed tools (node LTS, etc.)..."
        mise install
    fi
}

# --- Secrets ---

# Copy secrets template if no secrets file exists yet
copy_secrets_template() {
    local SECRETS_FILE="$HOME/.config/secrets/env"
    if [[ ! -f "$SECRETS_FILE" ]]; then
        echo "Creating secrets file from template..."
        mkdir -p "$(dirname "$SECRETS_FILE")"
        cp "$DOTFILES_DIR/secrets/env.example" "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
        echo "⚠ Fill in API keys at: $SECRETS_FILE"
    fi
}

# --- GitHub CLI ---

ensure_gh_auth() {
    if ! command -v gh &> /dev/null; then
        echo "⚠ GitHub CLI (gh) not installed, skipping auth check"
        return 1
    fi
    if gh auth status &> /dev/null; then
        return 0
    fi
    echo ""
    echo "GitHub CLI is installed but not authenticated."
    echo "This is needed to clone private repos (e.g. pi-extensions)."
    read -rp "Run 'gh auth login' now? [Y/n] " response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        gh auth login
        return $?
    fi
    echo "Skipped. Run 'gh auth login' later to enable private repo access."
    return 1
}

# --- Neovim ---

# Sync nvim plugins + treesitter parsers with the deployed config.
# Called after stow so that a new lazy-lock.json from another machine
# is reconciled before the user opens nvim.
sync_nvim_plugins() {
    if ! command -v nvim &> /dev/null; then return; fi

    echo "Syncing nvim plugins to lock file..."
    timeout 120 nvim --headless "+Lazy! restore" +qa 2>/dev/null || true

    echo "Syncing treesitter parsers..."
    timeout 120 nvim --headless "+TSUpdateSync" +qa 2>/dev/null || true
}

# --- Stow ---

# Run stow_dotfiles.sh with optional flags (e.g. --vps)
run_stow_dotfiles() {
    echo "Running stow script..."
    chmod +x "$DOTFILES_DIR/stow/stow_dotfiles.sh"
    "$DOTFILES_DIR/stow/stow_dotfiles.sh" "$@"
}
