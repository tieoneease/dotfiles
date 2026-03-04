# Claude Guidelines for Dotfiles Repository

## Primary Platform
- **OS:** EndeavourOS (Arch Linux), CachyOS (GPD Win Max 2)
- **Compositor:** Niri (scrollable tiling Wayland compositor)
- **Desktop Shell:** Noctalia Shell (status bar, app launcher, notifications, wallpaper/theming)
- **Secondary platform:** macOS (Aerospace, Sketchybar, Karabiner-Elements)

## Commands
- **Full setup:** `just setup` (auto-detects platform, runs the right setup script)
- **Arch/EndeavourOS Setup:** `just setup` or `./arch_setup.sh` (installs packages, configures system, stows dotfiles)
- **macOS Setup:** `just setup` or `./macos_setup.sh` (installs required software for macOS)
- **VPS Setup:** `just setup` or `./vps_setup.sh` (headless server dev environment)
- **Stow dotfiles:** `just stow` or `./stow/stow_dotfiles.sh` (symlinks all config files per-package)
- **Pi setup:** `just pi` or `./pi_setup.sh` (clones pi-extensions from GitHub, installs package, sets up subagent extension and agent definitions)
- **Noctalia QML patches:** `just patch-noctalia` or `sudo bash ./patch_noctalia.sh` (idempotent patches to system QML files; called by arch_setup.sh)
- **Font cache refresh:** `just fonts` or `fc-cache -f`

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
- **Pi Coding Agent:** Custom extensions package + skills (see `~/Workspace/pi-extensions/`, `pi_setup.sh`)
- **File Manager:** Yazi (terminal file manager, imv for images, glow + md-browser for markdown/mermaid)
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
- **sleep-inhibitor:** Replaces built-in KeepAwake. Uses `systemd-inhibit --what=sleep --mode=block` to block suspend/hibernate while allowing screen blanking (swayidle timeout). The built-in KeepAwake uses `--what=idle` which also prevents screen off. Combined with `LidSwitchIgnoreInhibited=no` in logind, this actually blocks lid-close suspend. A lid display handler (`lid-display-handler.sh`) powers off monitors on lid close when inhibited. Power button always suspends via logind (`PowerKeyIgnoreInhibited=yes`). Has CC widget (coffee icon) and IPC (`qs -c noctalia-shell ipc call plugin:sleep-inhibitor toggle`). Plugin `settings.json` files are gitignored (runtime state).
- **screen-toggle:** Toggles secondary screen (eDP-2) on Zenbook Duo devices. Self-hides when hardware not detected.
- **lte-status:** LTE modem status indicator.

## Yazi (file manager)
- **Config schema:** yazi v26+ uses `url` (not `name`) for filename patterns, `[mgr]` (not `[manager]`), and `prepend_rules`/`prepend_preloaders`/`prepend_previewers` to extend built-in defaults.
- **Image viewer:** imv (Wayland-native, lightweight)
- **Markdown preview:** Enter on `.md` → glow (terminal render, `q` to quit). Shift+O → pick "Render Markdown (browser + mermaid)" for full Chrome preview with mermaid diagrams, syntax highlighting.
- **Mermaid diagrams:** Standalone `.mmd`/`.mermaid` files render in Chrome via `md-browser`. Alternative: `mmdc` (mermaid-cli, via mise) renders to PNG → imv.
- **`md-browser` script:** `yazi/.local/bin/md-browser` — generates self-contained HTML using marked.js + mermaid.js + highlight.js from CDN, opens in Chrome. No server-side tools needed.
- **Open rules:** `.md`/`.mdx` and `.mmd`/`.mermaid` `url` rules are prepended before the `text/*` catch-all in `yazi.toml`.

## Arch Linux / EndeavourOS Setup
- **Setup script:** `./arch_setup.sh` (yay packages, keyd, greetd, sudoers, stow)
- **Idempotent re-runs:** All setup scripts are safe to re-run. Packages check `pacman -Qi` before installing, config files use `cp -f`, stow uses `--restow`, `~/.zshrc` loader checks for its marker before writing (preserving machine-specific additions), optional sections (ASUS, gaming) skip their prompt if already installed, and `pkgfile -u` skips if updated within 24 hours.
- **Noctalia patches:** `patch_noctalia.sh` (standalone, idempotent — workspace icons, calendar, weather, tooltips, NIcon raw glyphs). Called by arch_setup.sh via `sudo bash`. Each patch has a guard (grep for marker or patched pattern) and warns if upstream QML changed. Re-applied after `noctalia-shell-git` package updates. Patches are for **UI-only** changes; behavioral changes should use the plugin system instead.
- **Suspend:** Both the Zenbook Duo and GPD Win Max 2 use s2idle (Low-power S0 idle, the kernel/firmware default). S3 deep sleep is available on the Zenbook Duo but causes failed resume on lid close. Power button handling is done by logind (not niri) to avoid the re-suspend bug (niri #2233). swayidle locks screen on 5min idle and before suspend.
- Niri compositor with dynamic Material Design 3 colors via Noctalia/matugen
- Passwordless sudo setup for Claude Code (opt-in with confirmation prompt)
- keyd keyboard layers (numpad, nav, media)
- See `NIRI-SETUP.md` for detailed architecture docs

## Pi Coding Agent
- **Extensions package:** `~/Workspace/pi-extensions/` — a standalone private GitHub repo ([tieoneease/pi-extensions](https://github.com/tieoneease/pi-extensions)) containing custom extensions, skills, prompt templates, and agent definitions. Installed via `pi install ~/Workspace/pi-extensions`, which adds it to `~/.pi/agent/settings.json` `packages` array.
- **Setup script:** `./pi_setup.sh` (standalone, called by arch_setup.sh and macos_setup.sh) — clones pi-extensions from GitHub (requires `gh auth`), installs agent-browser, extensions package, sets up subagent extension, copies agent definitions. Idempotent: cleans up stale package paths from `settings.json` (e.g., after repo moves) before installing.
- **GitHub CLI:** `gh` (github-cli) installed by setup scripts, authenticated via `ensure_gh_auth` in `setup/common.sh`. Required to clone the private pi-extensions repo on new machines.
- **Subagent extension:** Symlinked from pi's examples to `~/.pi/agent/extensions/subagent/` (re-linked on pi version updates by pi_setup.sh)
- **Agent definitions:** `~/Workspace/pi-extensions/agents/` — subagent agent definitions (not auto-discovered by pi packages, copied to `~/.pi/agent/agents/` by pi_setup.sh). Contains `researcher.md`.
- **Per-machine config:** Use `pi config` to enable/disable individual extensions or skills on each machine — no dotfiles changes needed
- **Adding extensions/skills/agents:** Edit `~/Workspace/pi-extensions/` directly — extensions, skills, and prompt templates auto-load via the package manifest; agents need `pi_setup.sh` to deploy
