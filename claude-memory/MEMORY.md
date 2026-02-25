# Dotfiles Memory

## Niri Workspace Ordering & Dual-Screen Persistence

**Source-confirmed behavior** (layout/mod.rs): `ensure_named_workspace()` prepends new workspaces to index 0 on config reload. Existing workspaces are skipped. But `remove_output`/`add_output` preserve workspace order during migration — no IPC reordering needed for dock/undock.

**Simplified implementation** (`zenbook-duo-dock.sh`):
- `ensure_workspace_config()`: One-time init. Greps for `open-on-output "eDP-2"` marker to detect stale 9-workspace default vs correct 18-workspace config. On first creation or upgrade, writes file + reloads + reorders via IPC. Steady-state: no-op.
- `apply_docked()`: `niri msg output eDP-2 off` + `write_nav_binds` + `write_window_rules "󰭹" "󰈚"` (chat/calendar → eDP-1 icons). Niri preserves workspace order natively during migration.
- `apply_undocked()`: `write_nav_binds` + `write_window_rules "󰍡" "󰧭"` (chat/calendar → eDP-2 icons) + `position_edp2_below`. Workspaces auto-migrate back with order preserved.
- `generate_defaults()`: Writes 9-workspace config for non-Zenbook devices only (hostname check skips Zenbook). Also creates `window-rules-ws.kdl` with eDP-1 icons if missing (single-monitor default).
- No config rewrite, reload, sleep, or IPC reordering during steady-state dock/undock cycles.

**Restart gotcha**: The dock script runs as a long-lived bash process. Updating the script on disk (via stow/commit) does NOT affect the running instance — bash already loaded the old functions. Must kill + relaunch the script (or restart niri session) after updating.

**Key behaviors**: Named workspaces persist after removing declarations. `focus-workspace "N"` treats numeric strings as indices — Nerd Font glyphs avoid ambiguity. Workspaces survive output on/off cycles. To reset workspace config (e.g. after icon changes), delete `monitor-workspaces.kdl` and restart session.

**Gotcha**: `ensure_workspace_config` must check file *content* (grep for eDP-2 marker), not just existence. The old `generate_defaults` (or a previous script version) may have left a 9-workspace file without `open-on-output` constraints, which would be treated as "already configured" by a naive existence check.

## Dark Mode System Integration

**Issue**: Apps don't detect dark mode even though Noctalia Shell has dark mode enabled.

**Root Cause**: Noctalia only themes specific apps via config generation (terminals, nvim, niri). It doesn't broadcast dark mode preference system-wide through standard mechanisms.

**Solution Implemented**:
- Created `gtk/` stow package with GTK 3/4 dark mode configs
- Set `gsettings org.gnome.desktop.interface color-scheme 'prefer-dark'`
- Added xdg-desktop-portal packages for modern app support
- GTK apps read from `~/.config/gtk-3.0/settings.ini`
- Portal-aware apps query xdg-desktop-portal for dark mode

**Files**: `gtk/` stow package (GTK 3/4 settings.ini), `etc/xdg-desktop-portal/portals.conf`, gsettings in arch_setup.sh.

**Detection order**: gsettings → GTK config files → GTK_THEME env var (GTK); xdg-desktop-portal color-scheme (browsers/portal-aware apps).

## Noctalia Theming Architecture

**Two types of templates:**
1. **Built-in templates** (niri, kitty, yazi, alacritty, gtk) — enabled in `settings.default.json` `activeTemplates`. Noctalia manages output files directly. Do NOT create stow files at their output paths — stow symlinks conflict with Noctalia's file writes.
2. **Custom user templates** (nvim, tmux, walker) — defined in `user-templates.toml` with input/output paths and post-hooks. Used for apps without built-in support or when you need custom styling.

**Critical rule**: Never commit static color files for apps that have built-in templates. The stow symlink prevents Noctalia from managing the file properly.

**Generated output paths (all gitignored):**
- niri: `~/.config/niri/noctalia.kdl` (built-in)
- kitty: `~/.config/kitty/themes/noctalia.conf` + `current-theme.conf` (built-in)
- yazi: `~/.config/yazi/flavors/noctalia.yazi/flavor.toml` (built-in)
- alacritty: `~/.config/alacritty/themes/noctalia.toml` (built-in)
- gtk: `~/.config/gtk-{3.0,4.0}/{gtk.css,noctalia.css}` (built-in via Template Processor)
- nvim: `~/.config/nvim/lua/noctalia_colors.lua` (custom template)
- tmux: `~/.config/tmux/colors.conf` (custom template)
- walker: `~/.config/walker/themes/noctalia/style.css` (custom template — built-in disabled)

**Niri include detection gotcha**: Noctalia's `template-apply.sh` greps for `include\s+["']noctalia\.kdl["']` in config.kdl. Using `include optional=true "./noctalia.kdl"` breaks the match (the `optional=true` sits between `include` and the path), causing Noctalia to re-append a duplicate include on every wallpaper change. Must use `include "./noctalia.kdl"` without `optional=true`.

**Nvim Color Template — Dark Mode Base16 Mapping**:
- MD3 **container** colors are **dark backgrounds** in dark mode — never use as accent/foreground slots
- MD3 **on_\*** and direct color tokens (primary, secondary, tertiary) for syntax highlighting
- base06/07 use `on_surface | lighten: 5.0/10.0` for light foreground progression
- Template loaded via `dofile()` in theming.lua to avoid `require()` cache issues

**matugen 4.0 Filter Compatibility**:
- `lighten` filter exists; `darken` does **NOT** exist
- Use `lighten: -X` as equivalent to darkening by X
- matugen processes all templates together — one broken filter blocks all

See `tmux-theming.md` for: template design, status bar color assignment (MD3 roles), pill shapes, Nerd Font glyph handling.

## WirePlumber Audio Fix (Discord/Slack Random Muting)

Stow package `wireplumber/` with `51-no-suspend.conf` — disables node suspension (`session.suspend-timeout-seconds = 0`) for all ALSA input/output nodes. Stock WirePlumber suspends idle audio nodes after ~5s, which causes Electron apps (Vesktop, Slack) to randomly lose mic/speaker streams during voice calls. Reset stale state: `rm -rf ~/.local/state/wireplumber/ && systemctl --user restart wireplumber pipewire pipewire-pulse`.

**Cork/duck policies investigated — not a problem**: WirePlumber's role-based policy defaults to `"mix"` for both `action.same-priority` and `action.lower-priority` (linking-utils.lua:41-43). No config sets them to "cork" or "duck". The policy module is effectively a no-op for cork/duck. Cannot disable `policy.linking.role-based` via profiles — `policy.standard` depends on it and WirePlumber crashes (exit code 78).

## PipeWire AGC Block (Vesktop Mic Volume Fix)

Stow package `pipewire/` with `pipewire-pulse.conf.d/10-block-source-volume.conf` — uses `block-source-volume` quirk to prevent Electron/Chromium WebRTC AGC from adjusting PulseAudio source volume. Matches by `application.process.binary` (electron, chromium, chrome, google-chrome-stable). Discord's in-app AGC toggle has no effect in Vesktop — the adjustment is at the Chromium WebRTC layer. See [Vesktop#161](https://github.com/Vencord/Vesktop/issues/161). Restart: `systemctl --user restart pipewire pipewire-pulse`.

## Bluetooth Configuration

`etc/bluetooth/main.conf`: `[Policy] AutoEnable = true` only. `Experimental = true` breaks Noctalia device discovery (Adv Monitor API churn). Standard discovery works fine without it.

## CachyOS Gaming Meta-Packages

Gaming block in `arch_setup.sh` branches on distro: detects CachyOS via `pacman -Si cachyos-gaming-meta` (repo availability check). CachyOS path auto-installs `cachyos-gaming-meta` + `cachyos-gaming-applications` (no prompt, no gamemode, no explicit GPU drivers — CachyOS handles those). Non-CachyOS (EndeavourOS) falls back to the original interactive prompt with manual package list.

## Zenbook Duo

See `zenbook-duo.md` for: detachable keyboard (DWT/palm rejection, DKMS), phantom WMI media key fix (hwdb scancode remapping), stylus/touch mapping fix (custom niri build).

**asusd hidraw FD leak** (asusctl 6.3.2): asusd leaks hidraw FDs on HID device reconnect (dock/undock, USB replug). After ~15 cycles, exhausts `HIDRAW_MAX_DEVICES` (64, kernel hardcoded). Symptoms: VIA/Vial WebHID picker empty, no `/dev/hidraw*` for new devices. `RuntimeMaxSec=86400` drop-in at `etc/systemd/system/asusd.service.d/restart.conf` restarts asusd daily. Immediate fix: `sudo systemctl restart asusd` + replug device.

## Screen Lock Configuration

**Swaylock Removed**:
- Removed swaylock screen locker from the setup (not needed for personal device)
- Simplified idle management: swayidle now only powers off monitors after 5 minutes
- Super+Alt+L keybind changed from screen lock to manual monitor power-off
- OLED burn-in protection maintained via monitor power-off without locking

## Workspace Nerd Font Icon Size Fix

**Issue**: Workspace names use Nerd Font glyphs (󰊯, 󰭹, 󰆍). They appeared too small at the default `textRatio: 0.50` because Nerd Font glyphs have built-in padding in their metrics.

**Failed Attempt**: Setting `fontFixedScale: 1.5` made workspace icons bigger but also made OSD volume/brightness text comically large (both use `fontFixed` via `NText.qml`). Bumping `pillSize` to 1.0 made pills oversized without helping icons (text still limited by `textRatio`).

**Solution**: Patch `Workspace.qml` line 89 `textRatio: 0.50` → `0.75`. This is a system file at `/etc/xdg/quickshell/noctalia-shell/Modules/Bar/Widgets/Workspace.qml`. OSD is unaffected because it uses `Style.fontSizeS × fontFixedScale`, not `textRatio`.

**Math**: `pillSize(0.8) × textRatio(0.75) × fontFixedScale(1.0) = 0.60` — matches the old `0.8 × 0.50 × 1.5 = 0.60`.

**Persistence**: `patch_noctalia.sh` applies the sed patch (called by `arch_setup.sh`). Will be overwritten by `noctalia-shell-git` updates — re-run `sudo bash patch_noctalia.sh` to re-apply.

## ZMK + keyd + XKB + niri Keybinding Stack

See `keybinding-stack.md` for full signal flow, modifier segregation, and workspace binding table.

**Key design**: LeftAlt = app shortcuts/numpad (`[lower:A]`), RightAlt = workspace control/tab mgmt (`[altgr:G]`). Super+number freed. `[altgr+shift]` sends `A-S-*` (Alt+Shift) for niri move bindings. RightAlt+number works because keyd `MOD_ALT_GR` emits `KEY_RIGHTALT` → XKB `lv3:ralt_switch` → `ISO_Level3_Shift`.

**Layer rename `alt` → `lower`**: keyd's built-in `alt` modifier name causes guard modifier injection (Issue #257) that breaks composite layers. Renamed to `lower` (custom name) with `:A` suffix to preserve Alt modifier passthrough. Composite `[lower+altgr]` for BothAlts combos. Voice trigger moved to BothAlts+T (`t = f14`) because `v` still conflicts with `[lower:A] v = 3` even after rename.

**Gotcha**: keyd #823 — Shift+AltGr ordering may matter for `ISO_Level3_Shift+Shift+*` bindings.

## Keyd Scroll Binding Attempt (Failed)

keyd `command()` is non-functional in v2.6.0 — commands never execute. Reverted to `m = pagedown` / `comma = pageup`. For smooth scrolling, need alternative approach outside keyd.

## Niri spawn vs spawn-sh for Scripts in ~/.local/bin

**Issue**: `spawn "focus-or-launch" ...` keybinds silently failed — no error, no action.

**Root Cause**: niri's `spawn` does NOT include `~/.local/bin` in PATH, and bare command names won't resolve. Even `spawn "~/.local/bin/focus-or-launch"` didn't work because `spawn` doesn't do tilde expansion (it's not a shell).

**Fix**: Use `spawn-sh` which runs through `sh -c`, getting proper shell PATH and tilde expansion:
```kdl
Mod+O { spawn-sh "~/.local/bin/focus-or-launch obsidian obsidian"; }
```

**Rules**:
- Always use `spawn-sh` (not `spawn`) when invoking scripts from `~/.local/bin` in niri keybinds.
- For chained scripts (e.g. focus-or-launch → webapp-launch), use full `~/.local/bin/` paths for all executables since niri's env won't have them in PATH.

**Chromium --class ignored**: Chromium `--app` mode ignores `--class` and generates its own app_id from the URL (e.g. `chrome-web.whatsapp.com__-Default`). Always check `niri msg --json windows | jq '.[].app_id'` to get the real app_id for window rules.

**Confirmed Chromium webapp app_ids** (check with `niri msg --json windows | jq '.[].app_id'`):
- WhatsApp: `chrome-web.whatsapp.com__-Default`
- Gemini: `chrome-gemini.google.com__app-Default` (double underscore — URL path `/app` gets `__` separator)
- Perplexity: `chrome-www.perplexity.ai__-Default`
- NotebookLM: `chrome-notebooklm.google.com__-Default`
- Google Calendar: `chrome-calendar.google.com__-Default`
- YouTube: `chrome-www.youtube.com__-Default`
- Messenger: `chrome-www.messenger.com__-Default`
- Google Tasks: `chrome-tasks.google.com__embed_-Default` (trailing slash in URL produces `embed_`)

**webapp-install ICO gotcha**: `magick` can't decode `.ico` — use `apple-touch-icon.png` or Wikimedia SVG PNG instead.

**niri config reload**: `niri msg action reload-config` doesn't exist — correct command is `niri msg action load-config-file`.

## Walker Launcher (replaced Fuzzel)

**Migration**: Replaced `fuzzel` with `walker-bin` + `elephant-all` (provides all providers: calc, clipboard, desktop apps, files, runner, websearch, symbols).

**Key Details**:
- **Custom Noctalia template** — built-in walker template disabled (`enabled: false` in `settings.default.json`), replaced with minimal custom CSS via `user-templates.toml`. Flat design: no box-shadow, 1px borders, 8px radius, `primary_container` selection.
- Custom `layout.xml` in stow (500x400, compact) — only `style.css` is gitignored (generated output)
- Config at `walker/.config/walker/config.toml` (stow package)
- Niri keybind: `Alt+Space` spawns `walker` (uses `spawn` not `spawn-sh` since walker is in PATH)
- **Elephant daemon**: Walker's backend (`elephant-all` package) provides data via Unix socket. Must run as systemd user service (`elephant service enable && systemctl --user enable elephant.service`) or walker blocks with "waiting for elephant" on launch. Enabled in `arch_setup.sh`.

## Zathura PDF Viewer

- Packages: `zathura zathura-pdf-mupdf` (in arch_setup.sh productivity section)
- Stow package: `zathura/.config/zathura/zathurarc` (basic config)
- Default PDF handler set via `xdg-mime default org.pwmt.zathura.desktop application/pdf` in arch_setup.sh

## arch_setup.sh Service Enable Ordering

Services with unit files from system packages (installed via yay) can be enabled early:
- `noctalia.service`, `elephant.service` — enabled before stow

Services with unit files from stow packages must be enabled **after** stow runs + `daemon-reload`:
- `dotoold.service`, `voice-recorder.service`, `walker.service`

## Electron Apps on Wayland

**Per-app behavior varies**:
- **Slack**: Native Wayland works on Electron 39.2.4+. Use `--ozone-platform=wayland --disable-features=WaylandWindowDecorations` to run native Wayland without CSD title bar. App_id: `Slack`.
- **Vesktop** (Discord client): Uses Electron 40, defaults to native Wayland automatically — no flags needed. Replaced `discord_arch_electron` which had a fatal blank-screen bug (Electron 39 `ready-to-show` never fires on Wayland). Package: `vesktop-bin`. App_id: `vesktop`. Screen sharing works via PipeWire/Venmic.
- **Pencil.dev**: Native Wayland works fine. Use `--disable-features=WaylandWindowDecorations` for frameless window. `--ozone-platform=x11` causes it to hijack Chrome's session (opens a Chrome tab instead). App_id: `Pencil`.
- **Obsidian**: Native Wayland works fine. App_id: `obsidian`.
- **Chromium webapps** (WhatsApp, Gemini, Perplexity, NotebookLM): `--disable-features=WaylandWindowDecorations` added in `webapp-launch` script removes CSD title bar. Regular Chrome browsing unaffected.

**CSD title bar removal**: `--disable-features=WaylandWindowDecorations` gives frameless windows on niri. `--ozone-platform=x11` pitfall: can hijack Chrome session — only use when native Wayland is broken.

## Pencil.dev Design Tool

- **Install**: AppImage at `~/.local/share/pencil/Pencil.AppImage` (239MB), downloaded by `arch_setup.sh`
- **Stow**: `pencil/` package — `.desktop` entry + SVG icon
- **Dep**: `fuse2` (required for AppImage mounting)
- **App_id**: `Pencil` (native Wayland, StartupWMClass set)
- **Flags**: `--disable-features=WaylandWindowDecorations` in `.desktop` Exec for frameless window
- **Launcher**: Appears in Walker as "Pencil"
- **MCP**: Not needed for Claude Code CLI. Pencil's built-in Claude chat uses Agent SDK directly (not MCP). The MCP server is only for external tools to access `.pen` files. Pencil auto-registers MCP with CLI tools via `enabledIntegrations` in `~/.config/Pencil/config.json` — `claudeCodeCLI` toggled off in Pencil's menu to prevent auto-addition to `~/.claude/settings.json`.


## Nvim Tmux-Sessionizer Keybinding

`Ctrl+F` in nvim → `tmux display-popup -E tms` (full picker, auto-closes on select).
`tms switch` only shows *other* sessions — shows empty list when only one session exists. Always use bare `tms` for the picker. File: `nvim/.config/nvim/lua/keymaps.lua`.

## Nvim Markdown Rendering

`render-markdown.nvim` — lazy-loads on `ft = markdown`. Normal mode renders inline, insert mode shows raw text. Config: `plugins.lua` + `after/plugin/render-markdown.lua`.

## Google Calendar Sync (khal + vdirsyncer)

See `calendar-sync.md` for full details. GCP project `vdirsyncer-cal-859530`, CalDAV API (not JSON), 3 accounts (tieoneease, chungsam95, peachystudio). Stow package: `vdirsyncer/`. Timer syncs every 5min. Noctalia auto-detects khal.

## Noctalia Calendar Tooltip Patches

**Redesigned** calendar hover tooltip from plain text to sorted two-column grid:
- `settings.default.json`: `use12hourFormat: true` for AM/PM times
- `arch_setup.sh` patches (3 system files, reapplied on Noctalia updates):
  - `Tooltip.qml`: `maxWidth: isGridMode ? 560 : 340`, grid `width` constraint, last-column `Layout.fillWidth` (triggers NText's built-in `elide: Text.ElideRight`)
  - `CalendarMonthCard.qml`: `onEntered` handler replaced via Python `re.sub` (heredoc + lambda to avoid `\u` regex replacement issues). Sorts all-day first → chronological, passes 2-column `rows` array to `TooltipService.show()`, en-dash separator
- **Patching approach**: Python heredoc (`<< 'PATCH_EOF'`) for multi-line QML replacement; sed for single-property patches. `re.subn` with lambda replacement avoids regex replacement string parsing issues with Unicode escapes.

## mise (replaced NVM)

**Migration**: Replaced NVM with `mise` (Rust-based universal version manager). Eliminates ~220ms shell startup overhead.
- **Arch package**: `mise` (in `extra` repo, NOT `mise-bin` — that AUR package doesn't exist)
- **Stow package**: `mise/.config/mise/config.toml` — declares `node = "lts"`
- **Shell init**: `eval "$(mise activate zsh)"` in `base.zsh` (after plugins, before starship/direnv)
- **NVM removed from**: `.zshenv` (exports), `base.zsh` (sourcing), `arch_setup.sh`, `macos_setup.sh`
- **Tool install**: `mise install` runs post-stow in `arch_setup.sh` (needs deployed config)
