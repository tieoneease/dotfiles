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
- **Pi setup:** `./pi_setup.sh` (installs extensions package, clones pi-skills)
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
- **Pi Coding Agent:** Custom extensions package + skills (see `pi-package/`, `pi_setup.sh`)
- **macOS Tools:** Aerospace, Sketchybar, Karabiner-Elements

## Theming (Noctalia + matugen)
**Documentation:** Consult https://docs.noctalia.dev/ for Noctalia Shell configuration, features, and theming details.

Dynamic Material Design 3 colors generated from the current wallpaper:
- **Engine:** matugen extracts colors from wallpaper, Noctalia Shell triggers generation
- **Built-in templates:** Noctalia has built-in templates for niri, kitty, yazi, and fuzzel — enabled in `settings.default.json` `activeTemplates`. Do NOT create stow files at their output paths (they would conflict).
- **Custom user templates:** `noctalia/.config/noctalia/templates/` + `user-templates.toml` for apps without built-in support (nvim, tmux)
- **Generated files (all gitignored):** `noctalia.kdl` (niri), `themes/noctalia.conf` (kitty), `flavors/noctalia.yazi/` (yazi), `noctalia_colors.lua` (nvim), `colors.conf` (tmux)
- **Wallpapers:** `wallpapers/` contains defaults, copied to `~/Pictures/Wallpapers/` by setup script (not stowed — directory holds user content)

## Noctalia Plugins (custom, stowed)
Local plugins in `noctalia/.config/noctalia/plugins/`:
- **sleep-inhibitor:** Replaces built-in KeepAwake. Uses `systemd-inhibit --what=sleep` to block suspend/hibernate while allowing screen blanking (swayidle timeout). The built-in KeepAwake uses `--what=idle` which also prevents screen off. Has CC widget (coffee icon) and IPC (`qs -c noctalia-shell ipc call plugin:sleep-inhibitor toggle`). Plugin `settings.json` files are gitignored (runtime state).
- **screen-toggle:** Toggles secondary screen (eDP-2) on Zenbook Duo devices. Self-hides when hardware not detected.
- **lte-status:** LTE modem status indicator.

## Arch Linux / EndeavourOS Setup
- **Setup script:** `./arch_setup.sh` (yay packages, keyd, greetd, sudoers, stow)
- **Noctalia patches:** `patch_noctalia.sh` (standalone, idempotent — workspace icons, calendar, weather, tooltips, NIcon raw glyphs). Called by arch_setup.sh via `sudo bash`. Each patch has a guard (grep for marker or patched pattern) and warns if upstream QML changed. Re-applied after `noctalia-shell-git` package updates. Patches are for **UI-only** changes; behavioral changes should use the plugin system instead.
- **Deep sleep (S3):** `etc/systemd/sleep.conf.d/10-deep-sleep.conf` sets `MemorySleepMode=deep` for ASUS laptops (deployed by arch_setup.sh ASUS section only). GPD Win Max 2 only supports s2idle, so this is not deployed there.
- Niri compositor with dynamic Material Design 3 colors via Noctalia/matugen
- Passwordless sudo setup for Claude Code (opt-in with confirmation prompt)
- keyd keyboard layers (numpad, nav, media)
- See `NIRI-SETUP.md` for detailed architecture docs

## Pi Coding Agent
- **Extensions package:** `pi-package/` — a local pi package containing custom extensions (question, questionnaire, multiselect UI tools). Installed via `pi install ~/dotfiles/pi-package`, which adds it to `~/.pi/agent/settings.json` `packages` array. Extensions are NOT in the auto-discover path (`~/.pi/agent/extensions/`) — they load via the package system.
- **Setup script:** `./pi_setup.sh` (standalone, called by arch_setup.sh) — installs the extensions package and clones pi-skills repo
- **Skills:** pi-skills git repo cloned to `~/.pi/agent/skills/pi-skills/` (brave-search, browser-tools, etc.)
- **Per-machine config:** Use `pi config` to enable/disable individual extensions or skills on each machine — no dotfiles changes needed
- **Adding extensions:** Create new `.ts` files in `pi-package/extensions/`, they auto-load via the package manifest
