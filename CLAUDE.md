# Claude Guidelines for Dotfiles Repository

## Commands
- **macOS Setup:** `./macos_setup.sh` (installs required software for macOS)
- **Stow dotfiles:** `./stow/stow_dotfiles.sh` (symlinks all config files)
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

## Environment Management
- Package manager: Homebrew (for macOS)
- Symlink manager: GNU Stow
- Do not modify system files directly, use appropriate config files

## Main Components
- **Shell:** Zsh with Starship prompt
- **Terminal:** Kitty
- **Editor:** Neovim
- **Multiplexer:** Tmux
- **macOS Tools:** Sketchybar, Aerospace, Karabiner-Elements