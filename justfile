# Dotfiles task runner
# Usage: just <recipe>    (run `just` with no args to list recipes)

set dotenv-load := false

# Default: list available recipes
default:
    @just --list

# Full setup (auto-detects platform)
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    case "$(uname -s)" in
        Linux)
            if [[ -f /etc/os-release ]] && grep -qiE 'arch|endeavour|cachyos' /etc/os-release; then
                echo "Detected Arch Linux — running arch_setup.sh"
                ./arch_setup.sh
            else
                echo "Detected Linux (non-Arch) — running vps_setup.sh"
                ./vps_setup.sh
            fi
            ;;
        Darwin)
            echo "Detected macOS — running macos_setup.sh"
            ./macos_setup.sh
            ;;
        *)
            echo "Unsupported platform: $(uname -s)"
            exit 1
            ;;
    esac

# Stow dotfiles only (re-symlink everything)
stow *FLAGS:
    ./stow/stow_dotfiles.sh {{FLAGS}}

# Pi coding agent setup (upgrade + extensions, subagent, agents)
pi:
    npm install -g @mariozechner/pi-coding-agent
    ./pi_setup.sh

# Patch Noctalia Shell QML files (requires sudo, Arch only)
patch-noctalia:
    sudo bash ./patch_noctalia.sh

# Upgrade pi coding agent to latest version
upgrade-pi:
    npm install -g @mariozechner/pi-coding-agent

# Refresh font cache
fonts:
    fc-cache -f
