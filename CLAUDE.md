# Claude Guidelines for Dotfiles Repository

## Commands
- **Arch/EndeavourOS Setup:** `./arch_setup.sh` (installs packages, configures system, stows dotfiles)
- **macOS Setup:** `./macos_setup.sh` (installs required software for macOS)
- **Stow dotfiles:** `./stow/stow_dotfiles.sh` (symlinks all config files per-package)
- **Font cache refresh:** `fc-cache -f -v`

## Code Style
- **Indentation:** 4 spaces (tabs expanded)
- **Line wrapping:** Avoid wrapping lines
- **File organization:** Follow existing component directory structure
- **Naming convention:** Use lowercase with underscores for filenames
- **Shell scripts:** Use bash shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`
- **Config files:** Follow format of existing config files per application
- **Error handling:** Check command existence before using, provide fallbacks
- **Comments:** Add descriptive comments for non-obvious configurations
- **Lua style:** Follow existing patterns in nvim config (see options.lua, plugins.lua)
- **KDL style:** Follow existing patterns in niri config (config.kdl)
- **QML style:** Follow existing patterns in noctalia plugins (lte-status/)

## Environment Management
- Package manager: Homebrew (for macOS), yay (for EndeavourOS/Arch)
- Symlink manager: GNU Stow (target=$HOME, per-package)
- System configs in `etc/` are copied by setup script (not stowed)
- Config paths follow XDG Base Directory spec (e.g., ~/.config/)

## Stow Structure
Each package mirrors the home directory:
- `nvim/.config/nvim/` → `~/.config/nvim/`
- `zsh/.zshenv` → `~/.zshenv`
- `zsh/.config/zsh/base.zsh` → `~/.config/zsh/base.zsh`

## Main Components
- **Shell:** Zsh with Starship prompt (layered: .zshenv + base.zsh + aliases.zsh)
- **Terminals:** Alacritty (primary), Kitty
- **Editor:** Neovim
- **Multiplexer:** Tmux with tmux-sessionizer
- **Compositor:** Niri (scrollable tiling Wayland)
- **Desktop Shell:** Noctalia Shell (bar, launcher, notifications, theming)
- **Keyboard:** keyd (tap-hold layers, system-level)
- **Login:** greetd + tuigreet → niri-session
- **macOS Tools:** Aerospace, Sketchybar, Karabiner-Elements

## Arch Linux / EndeavourOS Setup
- **Setup script:** `./arch_setup.sh` (yay packages, keyd, greetd, stow)
- Niri compositor with dynamic Material Design 3 colors via Noctalia/matugen
- keyd keyboard layers (numpad, nav, media)
- See `NIRI-SETUP.md` for detailed architecture docs
