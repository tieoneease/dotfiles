#!/usr/bin/env bash

set -euo pipefail

# Pi coding agent setup: install custom extensions package and skills
# Can be run standalone or called by arch_setup.sh / macos_setup.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_PACKAGE_DIR="$DOTFILES_DIR/pi-package"
PI_SKILLS_DIR="$HOME/.pi/agent/skills/pi-skills"
PI_SETTINGS="$HOME/.pi/agent/settings.json"

# --- Extensions package ---

install_extensions_package() {
    local pi_package_path
    pi_package_path="$(realpath "$PI_PACKAGE_DIR")"

    # Check if already installed by looking for the path in settings.json
    if [[ -f "$PI_SETTINGS" ]] && grep -q "$pi_package_path" "$PI_SETTINGS" 2>/dev/null; then
        echo "Pi extensions package already installed."
        return
    fi

    echo "Installing pi extensions package from $pi_package_path..."
    pi install "$pi_package_path"
}

# --- Skills ---

install_skills() {
    if [[ ! -d "$PI_SKILLS_DIR" ]]; then
        echo "Cloning pi-skills..."
        mkdir -p "$(dirname "$PI_SKILLS_DIR")"
        git clone https://github.com/badlogic/pi-skills "$PI_SKILLS_DIR"
    else
        echo "Updating pi-skills..."
        git -C "$PI_SKILLS_DIR" pull --ff-only || echo "⚠ pi-skills pull failed (offline or conflict)"
    fi

    # Install npm dependencies for skills that need them
    for dir in "$PI_SKILLS_DIR"/*/; do
        if [[ -f "$dir/package.json" && ! -d "$dir/node_modules" ]]; then
            echo "  npm install in $(basename "$dir")..."
            (cd "$dir" && npm install --silent)
        fi
    done

    # Disable unused skills (keep brave-search + browser-tools) if not already configured
    if [[ -f "$PI_SETTINGS" ]] && ! grep -q '"skills"' "$PI_SETTINGS"; then
        echo "Disabling unused pi skills (keeping brave-search, browser-tools)..."
        local TMP_SETTINGS
        TMP_SETTINGS=$(mktemp)
        node -e "
            const s = JSON.parse(require('fs').readFileSync('$PI_SETTINGS', 'utf8'));
            s.skills = [
                '-skills/pi-skills/gccli/SKILL.md',
                '-skills/pi-skills/gdcli/SKILL.md',
                '-skills/pi-skills/gmcli/SKILL.md',
                '-skills/pi-skills/transcribe/SKILL.md',
                '-skills/pi-skills/vscode/SKILL.md',
                '-skills/pi-skills/youtube-transcript/SKILL.md'
            ];
            require('fs').writeFileSync('$TMP_SETTINGS', JSON.stringify(s, null, 2) + '\n');
        "
        mv "$TMP_SETTINGS" "$PI_SETTINGS"
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

    install_extensions_package
    install_skills

    echo "Pi setup complete."
    echo "  Extensions: pi list"
    echo "  Per-machine config: pi config"
}

main
