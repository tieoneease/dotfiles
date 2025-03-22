# Claude Guidelines for Dotfiles Repository

## Commands
- **Setup:** `./setup.sh` (main setup script)
- **Apply changes:** `home-manager switch` or `./nix/setup.sh`
- **Font cache refresh:** `fc-cache -f -v`
- **Stow dotfiles:** `stow --ignore=zsh .`

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
- Package manager: Nix/Home Manager
- Symlink manager: GNU Stow
- Do not modify system files directly, use appropriate config files