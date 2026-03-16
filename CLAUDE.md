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
- **VPS Setup:** `just setup` or `./vps_setup.sh` (headless server dev environment — zsh, nvim, tmux, mise, Rust, Claude Code, kitty terminfo, Tailscale SSH)
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
- **Shell:** Zsh with Starship prompt (layered: .zshenv + base.zsh + aliases.zsh). `EDITOR`/`VISUAL` set to nvim in base.zsh (portable — don't rely on `/etc/environment`).
- **Terminals:** Kitty (with `ssh-image-paste` for transparent image forwarding over SSH)
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

- **screen-toggle:** Toggles secondary screen (eDP-2) on Zenbook Duo devices. Self-hides when hardware not detected.
- **lte-status:** LTE modem status indicator. Requires `ModemManager.service` enabled (polls via `mmcli`).
- Keep-awake uses built-in Noctalia KeepAwake (`--what=idle`, blocks swayidle idle detection). Plugin `settings.json` files are gitignored (runtime state).

## Yazi (file manager)
- **Config schema:** yazi v26+ uses `url` (not `name`) for filename patterns, `[mgr]` (not `[manager]`), and `prepend_rules`/`prepend_preloaders`/`prepend_previewers` to extend built-in defaults.
- **Image viewer:** imv (Wayland-native, lightweight)
- **Markdown preview:** Enter on `.md` → glow (terminal render, `q` to quit). Shift+O → pick "Render Markdown (browser + mermaid)" for full Chrome preview with mermaid diagrams, syntax highlighting.
- **Mermaid diagrams:** Standalone `.mmd`/`.mermaid` files render in Chrome via `md-browser`. Alternative: `mmdc` (mermaid-cli, via mise) renders to PNG → imv.
- **`md-browser` script:** `yazi/.local/bin/md-browser` — generates self-contained HTML using marked.js + mermaid.js + highlight.js from CDN, opens in Chrome. No server-side tools needed.
- **Open rules:** `.md`/`.mdx` and `.mmd`/`.mermaid` `url` rules are prepended before the `text/*` catch-all in `yazi.toml`.

## SSH
- **Config:** `ssh/.ssh/config` (stowed to `~/.ssh/config`)
- **ControlMaster:** `Host *` enables connection multiplexing (`ControlMaster auto`, `ControlPath /tmp/ssh_mux_%r@%h-%p`, `ControlPersist 600`). First SSH connection becomes the master; subsequent SSH/SCP connections reuse it (no extra auth). Critical for `ssh-image-paste` — `scp` piggybacks on the existing session. **Incompatible with `kitten ssh`** — Kitty's SSH kitten bootstrap protocol breaks with multiplexed connections (partial terminal setup, broken key sequences in remote tmux). Use regular `ssh` instead; Kitty already forwards `TERM=xterm-kitty` and remotes have the terminfo installed.
- **ServerAliveInterval:** 60s keepalive prevents idle disconnects.

## Tailscale (mesh VPN + service access)
- **All machines** on the tailnet are directly reachable by MagicDNS short hostname (e.g., `sambot-vm`, `peachy-data`). No SSH port forwarding, Caddy, or Portless needed.
- **Dev servers:** Pi's dev-server extension starts servers and builds URLs as `http://<tailscale-hostname>:<port>` — accessible from any tailnet device (laptop, phone, iPad).
- **Persistent personal apps:** Use `tailscale serve --bg <port>` for auto-TLS HTTPS on the tailnet, or `tailscale serve --service=svc:NAME --bg --https=443 localhost:<port>` for named services with their own DNS entry (up to 10 on Personal plan).
- **Public sharing:** `tailscale funnel --bg <port>` exposes a service to the internet.

## Kitty (terminal)
- **SSH image paste:** `ssh-image-paste` script (`kitty/.local/bin/`) bound to Ctrl+V in kitty.conf. Auto-detects: (1) clipboard contains an image (`wl-paste --list-types`), (2) active Kitty window is an SSH session (`kitty @ ls` + jq to inspect `foreground_processes`). Both true → `wl-paste` grabs image → `scp` to remote `/tmp` → types the path into the terminal. Either false → passthrough raw Ctrl+V to the application (pi's `pasteImage`, etc.). SSH destination is parsed from the `ssh` cmdline (handles `user@host`, SSH config aliases, flags with arguments). SSH options (`-i`, `-p`, `-o`, `-F`) are forwarded to `scp` so connections via gcloud/IAP/custom keys work. Debug log at `/tmp/ssh-image-paste.log`. Requires: `wl-clipboard`, `jq`, `kitty` with `allow_remote_control socket-only` + `listen_on unix:/tmp/kitty`.

## Docker
- **Arch/VPS:** `docker`, `docker-compose`, `docker-buildx` via pacman. `docker.service` enabled, user added to `docker` group.
- **macOS:** Docker Desktop via `brew install --cask docker` (daemon + GUI). Docker CLI already in the brew formula line.
- All three setup scripts install and configure Docker automatically.

## Arch Linux / EndeavourOS Setup
- **Setup script:** `./arch_setup.sh` (yay packages, keyd, greetd, sudoers, stow)
- **Idempotent re-runs:** All setup scripts are safe to re-run. Packages check `pacman -Qi` before installing, config files use `cp -f`, stow uses `--restow`, `~/.zshrc` loader checks for its marker before writing (preserving machine-specific additions), optional sections (ASUS, gaming) skip their prompt if already installed, `pkgfile -u` skips if updated within 24 hours, and nvim plugins are synced to the deployed lock file (`Lazy! restore` + `TSUpdateSync`) after stow.
- **Noctalia patches:** `patch_noctalia.sh` (standalone, idempotent — workspace icons, calendar, weather, tooltips, NIcon raw glyphs). Called by arch_setup.sh via `sudo bash`. Each patch has a guard (grep for marker or patched pattern) and warns if upstream QML changed. Re-applied after `noctalia-shell-git` package updates. Patches are for **UI-only** changes; behavioral changes should use the plugin system instead.
- **Suspend:** Zenbook Duo uses s2idle. GPD Win Max 2 uses suspend-then-hibernate (s2idle for 15min, then hibernate to disk) because AMD Phoenix S0ix is broken. Power button handling is done by logind (not niri) to avoid the re-suspend bug (niri #2233). Noctalia `lockOnSuspend` locks screen before suspend. swayidle handles idle lock (5min) and DPMS (10min). See `POWER-MANAGEMENT.md` for full architecture and config details.
- **GPD Win Max 2 (`sam-ganymede`):** CachyOS, Quectel EC25 LTE modem (USB, `qmi_wwan`+`option` drivers). Setup installs `modemmanager`, enables `ModemManager.service`, and prompts for APN to create a GSM connection profile (`nmcli connection add type gsm`). LTE is configured as fallback: `autoconnect-priority -1`, `route-metric 1000` — wifi is always preferred when available. Also installs `bmi260-dkms` (IMU), `hhd` (handheld daemon), and amdgpu stability configs.
- Niri compositor with dynamic Material Design 3 colors via Noctalia/matugen
- Passwordless sudo setup for Claude Code (opt-in with confirmation prompt)
- keyd keyboard layers (numpad, nav, media, sleep-inhibitor toggle via RCtrl+K, translate via both-alts+R)
- **Translate clipboard:** `translate/` stow package — both alts + R (keyd F17 → XF86Launch8) reads clipboard, translates to English via `translate-shell` with romanization, shows GTK4 layer-shell overlay themed with noctalia colors, auto-saves to word bank at `~/.local/share/translate/words.json`. Chinese defaults to zh-TW. Deduplicates by original text.
- See `NIRI-SETUP.md` for detailed architecture docs

## Pi Coding Agent
- **Extensions package:** `~/Workspace/pi-extensions/` — a standalone private GitHub repo ([tieoneease/pi-extensions](https://github.com/tieoneease/pi-extensions)) containing custom extensions, skills, and agent definitions. Installed via `pi install ~/Workspace/pi-extensions`, which adds it to `~/.pi/agent/settings.json` `packages` array.
- **Setup script:** `./pi_setup.sh` (standalone, called by arch_setup.sh and macos_setup.sh) — clones pi-extensions from GitHub (requires `gh auth`), installs agent-browser, extensions package, sets up subagent extension, copies agent definitions. Idempotent: cleans up stale package paths from `settings.json` (e.g., after repo moves) before installing.
- **GitHub CLI:** `gh` (github-cli) installed by setup scripts, authenticated via `ensure_gh_auth` in `setup/common.sh`. Required to clone the private pi-extensions repo on new machines.
- **Subagent extension:** Owned in `~/Workspace/pi-extensions/extensions/subagent/` (auto-loaded via pi package manifest)
- **Agent definitions:** `~/Workspace/pi-extensions/agents/` — subagent agent definitions (not auto-discovered by pi packages, copied to `~/.pi/agent/agents/` by pi_setup.sh). Contains `researcher.md`.
- **Dev workflow extension:** Phase commands (`/discover`, `/spec`, `/build`) are extension commands in `extensions/dev-workflow/`, not standalone prompt templates. `/discover` is the unified entry point replacing the old `/idea`, `/research`, `/poc` — it combines conversational idea refinement with inline research/POC dispatch in one fluid session. `/spec` is collaborative; once approved, the build pipeline auto-chains: task breakdown (autonomous, fresh session) → build (autonomous, fresh session). Each command deterministically injects THREAD.md + primary artifact + file manifest into the agent message — no reliance on the agent reading the right files. `/ship` remains a standalone prompt template.
- **Subagent names:** Use `worker` (not `code`) for general-purpose coding/implementation tasks. Available agents: `scout` (recon), `planner` (plan), `worker` (implement), `reviewer` (review), `validator` (verify), `researcher` (extract notes), `research-lead` (multi-source research), `poc-lead` (POC experiment orchestration). There is no agent named `code`.
- **Dev server extension:** `dev_server` tool for non-blocking dev server lifecycle (start/status/logs/stop). Names are auto-namespaced by project (detected from package.json / git / cwd) — agent uses simple names like `name="api"` and tracks as `api.<project>`. State at `/tmp/pi-dev-server/<name>.<project>/` (pid, url, status, output.log) — readable by any process. URLs use Tailscale MagicDNS hostname when available (`http://<ts-hostname>:<port>`), accessible from any tailnet device. Active service URLs auto-injected into LLM context via `before_agent_start` for cross-service coordination. Shutdown only cleans up current project's servers.
- **Per-machine config:** Use `pi config` to enable/disable individual extensions or skills on each machine — no dotfiles changes needed
- **Adding extensions/skills/agents:** Edit `~/Workspace/pi-extensions/` directly — extensions and skills auto-load via the package manifest; phase command templates live in `extensions/dev-workflow/templates/`; agents need `pi_setup.sh` to deploy
