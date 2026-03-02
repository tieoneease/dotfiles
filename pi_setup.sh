#!/usr/bin/env bash

set -euo pipefail

# Pi coding agent setup: install extensions package, subagent, and agent definitions
# Can be run standalone or called by arch_setup.sh / macos_setup.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/setup/common.sh"

PI_EXTENSIONS_REPO="tieoneease/pi-extensions"
PI_EXTENSIONS_DIR="$HOME/Workspace/pi-extensions"
PI_SETTINGS="$HOME/.pi/agent/settings.json"
PI_AGENTS_DIR="$HOME/.pi/agent/agents"

# --- Agent browser ---

install_agent_browser() {
    if command -v agent-browser &> /dev/null; then
        echo "agent-browser already installed."
    else
        echo "Installing agent-browser..."
        npm install -g agent-browser
    fi

    # Install Chromium if not already present
    if [[ ! -d "$HOME/.cache/ms-playwright" ]] && [[ ! -d "$HOME/.cache/playwright" ]]; then
        echo "Installing Chromium for agent-browser..."
        agent-browser install
    else
        echo "Chromium already installed for agent-browser."
    fi
}

# --- Extensions package ---

clone_extensions_repo() {
    if [[ -d "$PI_EXTENSIONS_DIR" ]]; then
        echo "Pi extensions repo already present at $PI_EXTENSIONS_DIR"
        # Pull latest if it's a git repo
        if [[ -d "$PI_EXTENSIONS_DIR/.git" ]]; then
            echo "  Pulling latest..."
            git -C "$PI_EXTENSIONS_DIR" pull --ff-only 2>/dev/null || echo "  ⚠ Pull failed (offline or diverged)"
        fi
        return 0
    fi

    echo "Cloning pi-extensions to $PI_EXTENSIONS_DIR..."
    if ! command -v gh &> /dev/null; then
        echo "⚠ GitHub CLI (gh) not installed — cannot clone private repo"
        echo "  Install gh and run: gh auth login && gh repo clone $PI_EXTENSIONS_REPO $PI_EXTENSIONS_DIR"
        return 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "⚠ GitHub CLI not authenticated — cannot clone private repo"
        echo "  Run: gh auth login"
        echo "  Then: gh repo clone $PI_EXTENSIONS_REPO $PI_EXTENSIONS_DIR"
        return 1
    fi

    mkdir -p "$(dirname "$PI_EXTENSIONS_DIR")"
    gh repo clone "$PI_EXTENSIONS_REPO" "$PI_EXTENSIONS_DIR"
}

install_extensions_package() {
    if [[ ! -d "$PI_EXTENSIONS_DIR" ]]; then
        echo "⚠ Pi extensions repo not found at $PI_EXTENSIONS_DIR, skipping"
        return 1
    fi

    local ext_path
    ext_path="$(realpath "$PI_EXTENSIONS_DIR")"

    # Check if already installed by looking for the path in settings.json
    if [[ -f "$PI_SETTINGS" ]] && grep -q "$ext_path" "$PI_SETTINGS" 2>/dev/null; then
        echo "Pi extensions package already installed."
    else
        echo "Installing pi extensions package from $ext_path..."
        pi install "$ext_path"
    fi

    # Install npm deps for skills that need them
    if [[ -f "$PI_EXTENSIONS_DIR/skills/brave-search/package.json" ]]; then
        if [[ ! -d "$PI_EXTENSIONS_DIR/skills/brave-search/node_modules" ]]; then
            echo "  Installing brave-search dependencies..."
            (cd "$PI_EXTENSIONS_DIR/skills/brave-search" && npm install --silent)
        fi
    fi
}

# --- Subagent extension ---

install_subagent_extension() {
    local subagent_ext_dir="$HOME/.pi/agent/extensions/subagent"

    # Find pi's installed package path by following the pi binary symlink
    local pi_bin pi_cli pi_pkg_dir
    pi_bin="$(command -v pi 2>/dev/null)" || true
    if [[ -n "$pi_bin" ]]; then
        pi_cli="$(readlink -f "$pi_bin")"
        pi_pkg_dir="$(dirname "$(dirname "$pi_cli")")"
    fi

    if [[ -z "${pi_pkg_dir:-}" || ! -d "$pi_pkg_dir/examples/extensions/subagent" ]]; then
        echo "⚠ Could not find pi subagent extension source, skipping"
        return
    fi

    local subagent_src="$pi_pkg_dir/examples/extensions/subagent"
    mkdir -p "$subagent_ext_dir"

    # Symlink extension files (re-link on each run to follow pi version updates)
    ln -sf "$subagent_src/index.ts" "$subagent_ext_dir/index.ts"
    ln -sf "$subagent_src/agents.ts" "$subagent_ext_dir/agents.ts"
    echo "Subagent extension linked from $subagent_src"
}

# --- Agent definitions ---

install_agent_definitions() {
    mkdir -p "$PI_AGENTS_DIR"

    local agents_src="$PI_EXTENSIONS_DIR/agents"
    if [[ -d "$agents_src" ]]; then
        for agent_file in "$agents_src"/*.md; do
            [[ -f "$agent_file" ]] || continue
            local basename
            basename="$(basename "$agent_file")"
            cp "$agent_file" "$PI_AGENTS_DIR/$basename"
        done
        echo "Agent definitions installed to $PI_AGENTS_DIR"
    fi
}

# --- Main ---

main() {
    if ! command -v pi &> /dev/null; then
        echo "⚠ Pi coding agent not found, skipping setup"
        echo "  Install with: mise install npm:@mariozechner/pi-coding-agent"
        exit 0
    fi

    # Ensure ~/.pi/agent/ exists (pi creates it on first run, but we may run before that)
    mkdir -p "$HOME/.pi/agent"

    install_agent_browser
    clone_extensions_repo
    install_extensions_package
    install_subagent_extension
    install_agent_definitions

    echo "Pi setup complete."
    echo "  Extensions: pi list"
    echo "  Per-machine config: pi config"
}

main
