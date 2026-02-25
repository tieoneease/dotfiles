# Claude Guidelines for Dotfiles Repository

## Primary Platform
- **OS:** EndeavourOS (Arch Linux), CachyOS (GPD Win Max 2)
- **Compositor:** Niri (scrollable tiling Wayland compositor)
- **Desktop Shell:** Noctalia Shell (status bar, app launcher, notifications, wallpaper/theming)
- **Secondary platform:** macOS (Aerospace, Sketchybar, Karabiner-Elements)

## Commands
- **Arch/EndeavourOS Setup:** `./arch_setup.sh` (installs packages, configures system, stows dotfiles)
- **Noctalia QML patches:** `sudo bash ./patch_noctalia.sh` (idempotent patches to system QML files; called by arch_setup.sh)
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
- `claude/.claude/settings.json` → `~/.claude/settings.json`

## Main Components
- **Shell:** Zsh with Starship prompt (layered: .zshenv + base.zsh + aliases.zsh)
- **Terminals:** Kitty
- **Editor:** Neovim (base16-nvim for dynamic theming)
- **Multiplexer:** Tmux with tmux-sessionizer
- **Compositor:** Niri (scrollable tiling Wayland)
- **Desktop Shell:** Noctalia Shell (bar, launcher, notifications, theming)
- **Keyboard:** keyd (tap-hold layers, system-level)
- **Login:** greetd + tuigreet → niri-session
- **Claude Code:** Settings + statusline script (stow package targeting `~/.claude/`)
- **macOS Tools:** Aerospace, Sketchybar, Karabiner-Elements

## Theming (Noctalia + matugen)
**Documentation:** Consult https://docs.noctalia.dev/ for Noctalia Shell configuration, features, and theming details.

Dynamic Material Design 3 colors generated from the current wallpaper:
- **Engine:** matugen extracts colors from wallpaper, Noctalia Shell triggers generation
- **Built-in templates:** Noctalia has built-in templates for niri, kitty, yazi, and fuzzel — enabled in `settings.default.json` `activeTemplates`. Do NOT create stow files at their output paths (they would conflict).
- **Custom user templates:** `noctalia/.config/noctalia/templates/` + `user-templates.toml` for apps without built-in support (nvim, tmux)
- **Generated files (all gitignored):** `noctalia.kdl` (niri), `themes/noctalia.conf` (kitty), `flavors/noctalia.yazi/` (yazi), `noctalia_colors.lua` (nvim), `colors.conf` (tmux)
- **Wallpapers:** `wallpapers/` contains defaults, copied to `~/Pictures/Wallpapers/` by setup script (not stowed — directory holds user content)

## Arch Linux / EndeavourOS Setup
- **Setup script:** `./arch_setup.sh` (yay packages, keyd, greetd, sudoers, stow)
- **Noctalia patches:** `patch_noctalia.sh` (standalone, idempotent — workspace icons, calendar, weather, tooltips, NIcon raw glyphs). Called by arch_setup.sh via `sudo bash`. Each patch has a guard (grep for marker or patched pattern) and warns if upstream QML changed. Re-applied after `noctalia-shell-git` package updates.
- Niri compositor with dynamic Material Design 3 colors via Noctalia/matugen
- Passwordless sudo setup for Claude Code (opt-in with confirmation prompt)
- keyd keyboard layers (numpad, nav, media)
- See `NIRI-SETUP.md` for detailed architecture docs
