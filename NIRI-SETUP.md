# Desktop Environment Setup

Wayland-native tiling setup on Arch Linux.

| Component | Role |
|-----------|------|
| **Niri** | Scrollable tiling Wayland compositor |
| **Noctalia Shell** | Desktop shell (bar, launcher, notifications) — Kanagawa theme |
| **keyd** | Keyboard daemon for tap-hold and composite layers |
| **matugen** | Material Design 3 color extraction (called by Noctalia) |
| **Walker** | Application launcher (Wayland-native, elephant prewarming) |
| **xwayland-satellite** | XWayland server for X11 apps (Steam, etc.) |
| **greetd + tuigreet** | Login greeter — launches niri-session |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ greetd + tuigreet (VT1)                             │
│  └── Launches niri-session on login                 │
├─────────────────────────────────────────────────────┤
│ Niri (compositor)                                   │
│  ├── XKB: ctrl:nocaps, lv3:ralt_switch              │
│  ├── Key repeat: 200ms delay, 50 chars/sec          │
│  ├── xwayland-satellite (XWayland for X11 apps)      │
│  └── includes colors.kdl (auto-generated)           │
├─────────────────────────────────────────────────────┤
│ keyd (system-level, /etc/keyd/default.conf)         │
│  ├── LeftAlt tap-hold → alt layer (numpad)           │
│  ├── RightAlt tap-hold → altgr layer (tab mgmt)     │
│  ├── Both Alts → arrows + Home/End/Scroll            │
│  └── RightCtrl tap-hold → control (vol/brightness)  │
├─────────────────────────────────────────────────────┤
│ Noctalia Shell (systemd user service)               │
│  ├── Kanagawa color scheme                          │
│  ├── useWallpaperColors: true                       │
│  └── Calls matugen → generates color templates      │
│       ├── Built-in: niri, kitty, yazi               │
│       └── User: nvim, tmux, walker                  │
└─────────────────────────────────────────────────────┘
```

---

## greetd + tuigreet — Login Greeter

**Config:** `/etc/greetd/config.toml` (requires sudo)
**Service:** `greetd.service` (system-level, enabled)

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd niri-session"
user = "greeter"
```

tuigreet presents a TUI login prompt on VT1. On successful authentication it launches `niri-session`, which starts the compositor and user services (including Noctalia).

### Rollback

If greetd fails at boot, switch to another TTY (`Ctrl+Alt+F2`), log in, and run:

```bash
sudo bash ~/.config/rollback-greetd.sh
```

This disables `greetd.service`, re-adds `chungsam` to the `autologin` group, and resets the config to the default `agreety` greeter.

---

## keyd — Keyboard Layers

**Config:** `/etc/keyd/default.conf` (requires sudo, reload with `sudo keyd reload`)

keyd handles things XKB cannot: tap-hold (`overload()`), multi-key output, and composite layers. XKB continues to handle `ctrl:nocaps` and `lv3:ralt_switch` in niri.

### Layers

#### `[alt:A]` — LeftAlt held

Tap LeftAlt = LeftAlt. Hold LeftAlt + key = numpad digit.

The `:A` suffix means unmapped keys pass through with Alt — so `Alt+H/J/K/L` (niri focus) still works.

```
w e r         →  7 8 9
s d f         →  4 5 6
x c v b       →  1 2 3 0
```

`[alt+shift]` maps the same keys to `Shift+digit` (i.e. `!@#` etc.).

#### `[altgr:G]` — RightAlt held (Chrome tab management)

Tap RightAlt = RightAlt. Hold RightAlt + key = tab action.

The `:G` (AltGr) suffix means unmapped keys pass through as ISO_Level3_Shift — so niri's `RightAlt+X/C/V` workspace binds still work.

| Key | Sends | Action |
|-----|-------|--------|
| `h` | Ctrl+Shift+PageUp | Move tab left |
| `j` | Ctrl+Shift+Tab | Previous tab |
| `k` | Ctrl+Tab | Next tab |
| `l` | Ctrl+Shift+PageDown | Move tab right |

#### `[altgr+shift]` — RightAlt+Shift held (column/monitor movement)

Sends `Alt+Shift+H/J/K/L` so niri's move-column/move-column-to-monitor bindings work consistently from both Alt keys.

| Key | Sends | Niri action |
|-----|-------|-------------|
| `h` | Alt+Shift+H | Move column left |
| `j` | Alt+Shift+J | Move column to monitor down |
| `k` | Alt+Shift+K | Move column to monitor up |
| `l` | Alt+Shift+L | Move column right |

Unmapped keys fall through as `AltGr+Shift` → `ISO_Level3_Shift+Shift` → niri workspace move binds.

#### `[alt+altgr]` — Both Alts held (arrows and navigation)

This is a composite layer that activates when both LeftAlt and RightAlt are held simultaneously. It **must** appear after both constituent layers in the config file.

| Key | Output |
|-----|--------|
| `h` | Left |
| `j` | Down |
| `k` | Up |
| `l` | Right |
| `n` | Home |
| `m` | ScrollDown |
| `,` | ScrollUp |
| `.` | End |

#### `[control]` — RightCtrl held (volume and brightness)

Tap RightCtrl = RightCtrl. Hold RightCtrl + key = media/brightness control.

| Key | Output |
|-----|--------|
| `a` | Volume down |
| `s` | Volume up |
| `d` | Brightness down |
| `f` | Brightness up |

### Why keyd over XKB

- `overload()` (tap = one key, hold = modifier/layer) is impossible in XKB
- Multi-key output (e.g. `Ctrl+Shift+Tab`) requires keyd
- Composite layers ("both alts") require keyd
- keyd operates at evdev level, below the compositor — works everywhere

---

## Niri — Compositor

**Config:** `~/.config/niri/config.kdl`

### Key settings

```kdl
input {
    keyboard {
        xkb {
            options "ctrl:nocaps,lv3:ralt_switch"
        }
        repeat-delay 200
        repeat-rate 50
    }
    touchpad {
        tap
        dwt
        natural-scroll
    }
}
output "eDP-1" {
    scale 1.75
}
```

- **CapsLock → Ctrl** via `ctrl:nocaps`
- **RightAlt → ISO_Level3_Shift** via `lv3:ralt_switch` (used by niri workspace binds)
- **Key repeat:** 200ms delay, 50 characters/second

### Layout

- Gaps: 16px
- Default column width: 50% of output
- Preset widths: 1/3, 1/2, 2/3

### Dynamic colors

```kdl
include "./colors.kdl"
```

`colors.kdl` is auto-generated by matugen (via Noctalia) and overrides focus-ring, border, and shadow colors. The config has static Kanagawa fallbacks that are used until the first wallpaper-based generation.

### Named workspaces

Workspaces 1–9 are declared in `monitor-workspaces.kdl` (gitignored, generated on fresh
install by `stow_dotfiles.sh`). Each workspace is named with an MDI Nerd Font glyph
(all from the Supplementary PUA, U+F0xxx range) — the same icon set used by the Zenbook
Duo's eDP-1. The icon set is the single source of truth for both single-monitor and Zenbook
Duo eDP-1 workspaces:

| WS | Icon | Codepoint | Semantic use |
|----|------|-----------|--------------|
| 1 | 󰇧 | U+F01E7 | Home/general |
| 2 | 󰭹 | U+F0B79 | Chat/comms |
| 3 | 󰆍 | U+F018D | Code |
| 4 | 󰈚 | U+F021A | Docs |
| 5 | 󰅴 | U+F0174 | Terminal |
| 6 | 󰄨 | U+F0128 | Files |
| 7 | 󰍉 | U+F0349 | Media |
| 8 | 󰧑 | U+F09D1 | Brain (Obsidian/Gemini/Perplexity) |
| 9 | 󰳪 | U+F0CEA | Archive |

> **Note:** These icons are Supplementary PUA characters (4-byte UTF-8). They appear as
> blank boxes in Claude Code's Read tool output, making them tricky to edit directly — use
> Python with explicit codepoints when modifying workspace names in config files.

### Zenbook Duo — Dual Screen & Dock-Aware Config

On the Zenbook Duo (`sam-duomoon`), `zenbook-duo-dock.sh` spawns at startup and manages
three generated config files that adapt to dock/undock state:

| Generated file | Purpose | Dock-aware |
|----------------|---------|------------|
| `monitor-workspaces.kdl` | 18 workspace declarations (9 per screen) with `open-on-output` | No (static after init) |
| `monitor-nav.kdl` | Alt+J/K bindings | Yes |
| `window-rules-ws.kdl` | Chat/calendar app → workspace assignment | Yes |

**Dual-screen workspaces:** eDP-1 (top) gets the standard 9 icons above. eDP-2 (bottom)
gets 9 MDI variant icons (visually distinct but semantically matched). When docked (keyboard
attached, eDP-2 off), all 18 workspaces live on eDP-1. Niri preserves workspace order
natively across output on/off cycles.

**Dock-aware window rules** (`window-rules-ws.kdl`):

| Apps | Docked (eDP-1 only) | Undocked (dual screen) |
|------|---------------------|------------------------|
| vesktop, Slack, WhatsApp, Messenger | Chat workspace (eDP-1 icon) | Chat workspace (eDP-2 icon) |
| Google Calendar, Google Tasks | Calendar workspace (eDP-1 icon) | Calendar workspace (eDP-2 icon) |

Static window rules (YouTube → ws1, Obsidian/AI → ws8, Steam → ws9) remain in `config.kdl`
since they always target eDP-1 workspaces regardless of dock state.

**Single-monitor (non-Zenbook) flow:** `generate_defaults()` creates `window-rules-ws.kdl`
targeting the standard eDP-1 icons and `monitor-workspaces.kdl` with 9 workspaces (no
`open-on-output`). The script then exits — no dock monitoring needed.

**Dock state detection:** USB device `0b05:1b2c` (Zenbook Duo 2024 keyboard). The script
watches `udevadm monitor --subsystem-match=usb` for plug/unplug events with debouncing
for pogo-pin contact bounce.

> **Restart required:** If you update `zenbook-duo-dock.sh` (e.g. via stow), the running
> instance still has the old code in memory. Kill the old process and re-run the script,
> or restart the niri session.

### Key bindings (niri-native)

| Bind | Action |
|------|--------|
| `Mod+T` | Terminal (kitty) |
| `Alt+Space` | Walker launcher |
| `Super+B` | Chrome |
| `Super+Alt+L` | Turn off screen (DPMS) |
| `Mod+Q` | Close window |
| `Alt+H/J/K/L` | Focus left/down/up/right |
| `Alt+Shift+H/J/K/L` | Move window left/down/up/right |
| `ISO_Level3_Shift+1-9` | Focus workspace N (RightAlt+number) |
| `ISO_Level3_Shift+Shift+1-9` | Move column to workspace N (RightAlt+Shift+number) |
| `ISO_Level3_Shift+X/C/V/S/D/F/W/E/R` | Focus workspace 1–9 (RightAlt+numpad letter) |
| `ISO_Level3_Shift+Shift+...` | Move column to workspace 1–9 |
| `ISO_Level3_Shift+M/Comma` | Focus next non-empty workspace up/down (skips empty) |
| `Alt+P/N` | Focus next non-empty workspace up/down (skips empty) |
| `Alt+Shift+P/N` | Move column to workspace up/down |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+W` | Toggle tabbed column |
| `Mod+R` | Cycle preset widths |
| `Print` / `Mod+Shift+S` | Screenshot (select region → Space to clipboard + save) |

---

## Noctalia Shell — Desktop Shell

**Config:** `~/.config/noctalia/settings.json`
**Service:** systemd user unit

### Color pipeline

1. User selects wallpaper in Noctalia
2. Noctalia calls `matugen` to extract Material Design 3 colors from the wallpaper
3. matugen generates themed config files from templates
4. Post-hooks reload affected applications

### Settings

- **Color scheme:** Kanagawa (predefined), overridden by wallpaper colors when `useWallpaperColors: true`
- **Dark mode:** on
- **Generation method:** tonal-spot
- **Terminal command:** `kitty`
- **Launcher:** built-in (list view, center position, tabler icons)

### User templates

**Config:** `~/.config/noctalia/user-templates.toml`

These templates tell matugen to generate additional config files beyond Noctalia's built-in targets.

#### Neovim colors

- **Template:** `~/.config/noctalia/templates/nvim-colors.lua`
- **Output:** `~/.config/nvim/lua/noctalia_colors.lua`
- **Post-hook:** `pkill -SIGUSR1 nvim`

Exports Material Design color tokens as a Lua table for base16-nvim dynamic theming.

#### Tmux colors

- **Template:** `~/.config/noctalia/templates/tmux-colors.conf`
- **Output:** `~/.config/tmux/colors.conf`
- **Post-hook:** `tmux source-file ~/.config/tmux/tmux.conf`

Sets tmux status bar and pane border colors from Material Design tokens.

#### Tmux hyperlink passthrough

`terminal-features` includes `:hyperlinks` for all terminals so tmux forwards OSC 8 sequences (clickable links from `ls --hyperlink`, `gcc`, `grep`) to the outer terminal. `allow-passthrough on` enables escape sequence passthrough for kitty graphics protocol and other OSC sequences.

#### Walker CSS

- **Template:** `~/.config/noctalia/templates/walker-style.css`
- **Output:** `~/.config/walker/themes/noctalia/style.css`

Full GTK CSS theme for the walker launcher. Uses `* { all: unset }` then rebuilds styling with Material Design color tokens. Sets `font-family: "Sans Serif", sans-serif` and `font-size: 14px` on `.box-wrapper` so all children inherit Noto Sans at a comfortable size after the reset.

### Apps themed by Noctalia (built-in)

GTK 3/4, Qt, Niri, Kitty, Yazi, Foot, Ghostty, Fuzzel, Discord, Firefox

### Apps themed via user templates

Neovim, Tmux, Walker

---

## Kitty — Clickable URLs

**Kitty** (primary terminal):

| Action | Behavior |
|--------|----------|
| `Ctrl+Click` | Opens URL under cursor (works inside tmux) |
| `Ctrl+Shift+E` | Hint mode — labels each visible URL, type label to open |
| `Shift+Click` | Opens URL under cursor (Kitty default, works inside tmux) |

Uses `xdg-open` to open in the default browser. `Ctrl+Click` works inside tmux because `mouse_map` is configured with `grabbed` mode and `discard_event` prevents tmux from intercepting the click.

---

## XWayland — X11 Compatibility

**Started by:** `spawn-at-startup "xwayland-satellite"` in niri config

`xwayland-satellite` provides an XWayland server for X11 applications (Steam, some games, older tools). It starts with niri and sets `DISPLAY` so X11 apps work transparently.

Without it, X11 apps fail with "Unable to open a connection to X".

---

## Gaming

**Setup:** Gaming section in `arch_setup.sh` auto-detects the distro and branches accordingly.

### CachyOS (GPD Win Max 2)

Detected via `pacman -Si cachyos-gaming-meta` (checks repo availability). Installs automatically — no prompt:

| Package | Role |
|---------|------|
| `cachyos-gaming-meta` | Curated gaming stack (Steam, gamescope, MangoHud, Proton, wine, umu-launcher, protontricks, etc.) |
| `cachyos-gaming-applications` | Gaming utilities (Heroic launcher, ProtonPlus, etc.) |

GPU drivers, process scheduling (ananicy-cpp), and Proton (proton-cachyos-slr) are handled by CachyOS — no gamemode group or explicit Vulkan driver packages needed.

### EndeavourOS / other Arch (manual)

Prompted interactively (`Install gaming tools? [y/N]`):

| Package | Role |
|---------|------|
| `steam` | Game client |
| `gamescope` | SteamOS session compositor (per-game Wayland/XWayland) |
| `mangohud` / `lib32-mangohud` | FPS/performance overlay |
| `gamemode` / `lib32-gamemode` | CPU/GPU performance optimizer |
| `vulkan-radeon` / `lib32-vulkan-radeon` | AMD Vulkan drivers |
| `protonup-qt` | Proton-GE version manager |

### Niri window rules

```kdl
// Steam notification popups — bottom-right instead of center
window-rule {
    match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
    default-floating-position x=10 y=10 relative-to="bottom-right"
}

// Gamescope and Steam game windows — fullscreen with VRR
window-rule {
    match app-id="gamescope"
    open-fullscreen true
    variable-refresh-rate true
}
window-rule {
    match app-id=r#"^steam_app_\d+$"#
    open-fullscreen true
    variable-refresh-rate true
}
```

### Launch options

For gamescope (recommended for most games):
```
gamescope -f -w 1920 -h 1080 -W 1920 -H 1080 --force-grab-cursor --backend sdl -- %command%
```

### Troubleshooting

- **Steam black window:** Settings → Interface → disable GPU accelerated rendering
- **Proton compatibility:** Run `protonup-qt` to install GE-Proton

---

## GPU Stability — AMD Phoenix (GPD Win Max 2)

**Configs:** `/etc/modprobe.d/amdgpu.conf`, `/etc/udev/rules.d/99-amdgpu-power-stable.rules`
**Machine:** `sam-ganymede` only (deployed by `arch_setup.sh` hostname guard)

The AMD Phoenix1 iGPU (RDNA 3, amdgpu driver) freezes the display pipe when `power-profiles-daemon` switches profiles on charger plug/unplug. Two configs mitigate this:

### modprobe: gpu_recovery

```
options amdgpu gpu_recovery=1
```

Enables automatic GPU reset after a 10-second hang timeout. The default (`-1`) only enables recovery for SR-IOV (virtualization), so desktop use needs an explicit `1`. Does NOT set `dpm=` (default already enables DPM on Phoenix) or `runpm=0` (kills battery life on handhelds).

### udev: DPM stabilization on AC power change

On `power_supply` change events, briefly locks GPU DPM to `high` for 3 seconds (via `systemd-run --no-block` to avoid blocking udev), then restores `auto`. This prevents the GPU from being mid-DPM-transition when the power profile switch arrives.

### Verification

```bash
# Check modprobe params (after reboot)
cat /sys/module/amdgpu/parameters/gpu_recovery    # should be 1

# Monitor DPM level during charger plug/unplug
cat /sys/class/drm/card1/device/power_dpm_force_performance_level

# Watch udev events
udevadm monitor --property
```

---

## IMU + Gyro — BMI260 / Handheld Daemon (GPD Win Max 2)

**Configs:** `/etc/modprobe.d/blacklist-bmi160.conf`
**Packages:** `bmi260-dkms`, `hhd`, `game-devices-udev`
**Service:** `hhd@sam` (system-level, enabled)
**Machine:** `sam-ganymede` only (deployed by `arch_setup.sh` hostname guard)

The GPD Win Max 2 has a Bosch BMI260 accelerometer/gyroscope, but the BIOS misidentifies it as a BMI160. The upstream `bmi160` modules auto-load and fail to communicate with the chip.

### bmi160 blacklist

Blacklists `bmi160_spi`, `bmi160_i2c`, and `bmi160_core` so the correct `bmi260-dkms` driver can bind via IIO.

### Handheld Daemon (HHD)

HHD emulates a DualSense Edge controller, which is the only reliable gyro-capable emulation target on Linux handhelds. Steam Input detects the emulated controller and exposes gyro configuration (gyro aiming, flick stick, etc.).

`game-devices-udev` provides the udev rules needed for Steam to see the emulated DualSense Edge.

### Known issues

Community sources flag WM2 gyro as buggy — expect possible drift or axis mapping issues. This setup gets the infrastructure in place.

### Verification

```bash
lsmod | grep bmi160                    # should show nothing (blacklisted)
lsmod | grep bmi260                    # should show bmi260_i2c, bmi260_core
ls /sys/bus/iio/devices/               # should show an IIO device
systemctl status hhd@sam               # should show HHD running
```

Steam should detect a DualSense Edge controller with gyro capabilities in Settings > Controller.

---

## Wallpapers

**Directory:** `~/Pictures/Wallpapers/`

~395 images sourced from:

| Source | Content |
|--------|---------|
| [Gurjaka/Kanagawa-Wallpapers](https://codeberg.org/Gurjaka/Kanagawa-Wallpapers) | Kanagawa palette wallpapers |
| [dharmx/walls](https://github.com/dharmx/walls) | anime, chillop, calm, pixel, wave categories |
| [D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) | lo-fi, Japanese, mountain, city, pixel art |

Select wallpapers via Noctalia's wallpaper picker. Colors auto-apply to the shell, Niri borders, and Kitty.

---

## Noctalia Plugins

**Directory:** `~/.config/noctalia/plugins/`
**Registry:** `~/.config/noctalia/plugins.json`

Plugins are loaded by PluginService on startup. Enable/disable via Settings > Plugins or by editing `plugins.json`.

### lte-status — LTE Modem Indicator

Displays Quectel EG25G cellular modem status in the bar and control center using ModemManager (`mmcli`).

**Files:**

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin metadata; entry points: `main`, `barWidget`, `controlCenterWidget` |
| `Main.qml` | State manager — discovers modem via `mmcli -L -J`, polls `mmcli -m <index> -J` every 10s |
| `BarWidget.qml` | Bar pill: signal bars icon + tech label ("LTE"/"3G"/"H+") |
| `ControlCenterWidget.qml` | CC button: `NIconButtonHot`, lit when connected |
| `i18n/en.json` | English translations |

**How it works:**

1. On startup, runs `mmcli -L -J` to discover the modem D-Bus path (index may vary)
2. Polls `mmcli -m <index> -J` every 10 seconds using `Quickshell.Io.Process` + `StdioCollector`
3. Parses JSON to extract: state, signal quality (0–100), access technology, operator name
4. Exposes reactive properties consumed by bar and CC widgets
5. Falls back gracefully if no modem is found (`antenna-bars-off`, re-discovers on next poll)

**Signal icon mapping:**

| Signal | Icon |
|--------|------|
| >= 80% | `antenna-bars-5` |
| >= 60% | `antenna-bars-4` |
| >= 40% | `antenna-bars-3` |
| >= 20% | `antenna-bars-2` |
| < 20% | `antenna-bars-1` |
| Disconnected | `antenna-bars-off` |

**Tech labels:** `lte`→LTE, `umts`→3G, `hspa`→H+, `edge`→E, `5gnr`→5G

**Widget behavior:**
- Bar tooltip: "TW Mobile — LTE 78%"
- Click/right-click: shows toast with connection details
- CC button: `hot` (highlighted) when connected

**Key pattern:** Uses `StdioCollector` + `onStreamFinished` (not `SplitParser`) to collect full JSON output from `mmcli`, matching the pattern NetworkService uses for `nmcli`.

---

## File Map

```
/etc/greetd/config.toml                              # greetd greeter config (sudo)
/etc/keyd/default.conf                              # keyd layers (sudo)
/etc/modprobe.d/amdgpu.conf                          # amdgpu gpu_recovery (sam-ganymede only)
/etc/modprobe.d/blacklist-bmi160.conf                 # blacklist bmi160 for BMI260 IMU (sam-ganymede only)
/etc/udev/rules.d/99-amdgpu-power-stable.rules       # DPM stabilization on AC change (sam-ganymede only)
~/.config/
├── niri/
│   ├── config.kdl                                   # compositor config
│   ├── zenbook-duo-dock.sh                          # dock/undock management (spawns at startup)
│   ├── colors.kdl                                   # auto-generated by matugen
│   ├── monitor-workspaces.kdl                       # generated: workspace declarations
│   ├── monitor-nav.kdl                              # generated: dock-aware Alt+J/K binds
│   └── window-rules-ws.kdl                          # generated: dock-aware chat/calendar rules
├── noctalia/
│   ├── settings.json                                # shell settings
│   ├── plugins.json                                 # plugin registry (enabled states)
│   ├── user-templates.toml                          # matugen template registry
│   ├── templates/
│   │   ├── nvim-colors.lua                          # neovim color template
│   │   ├── tmux-colors.conf                         # tmux color template
│   │   └── walker-style.css                         # walker GTK CSS template
│   └── plugins/
│       └── lte-status/                              # LTE modem indicator plugin
│           ├── manifest.json
│           ├── Main.qml
│           ├── BarWidget.qml
│           ├── ControlCenterWidget.qml
│           └── i18n/en.json
├── systemd/user/
│   │   ├── dotoold.service                            # dotool daemon
│   │   ├── voice-recorder.service                     # voice-to-text daemon
│   │   └── walker.service                             # walker launcher (DBus activation)
├── rollback-greetd.sh                               # greetd rollback script
~/.local/bin/
├── voice-recorder                                     # voice-to-text daemon (Python)
├── voice-toggle                                       # sends SIGUSR1 to daemon
~/Pictures/
└── Wallpapers/                                      # ~395 wallpapers
```

### Auto-generated files (do not edit)

Noctalia/matugen templates:
- `~/.config/niri/noctalia.kdl`
- `~/.config/kitty/themes/noctalia.conf`
- `~/.config/yazi/flavors/noctalia.yazi/`
- `~/.config/nvim/lua/noctalia_colors.lua`
- `~/.config/tmux/colors.conf`
- `~/.config/walker/themes/noctalia/style.css`

zenbook-duo-dock.sh generated (dock/undock and first-boot):
- `~/.config/niri/monitor-workspaces.kdl`
- `~/.config/niri/monitor-nav.kdl`
- `~/.config/niri/window-rules-ws.kdl`

---

## Bluetooth — Keyboard Pairing

Noctalia Shell's Bluetooth UI can scan and connect to devices, but **does not display pairing PINs** for devices that require passkey entry (e.g. BLE keyboards). The pairing attempt silently fails with `AuthenticationFailed` because no agent handles the passkey display.

### Workaround: Pair via CLI

Use `bluetoothctl` with a D-Bus pairing agent that prints the passkey to stdout:

```bash
# 1. Enable pairing and scan
bluetoothctl pairable on
bluetoothctl --timeout 30 scan on

# 2. Find the device
bluetoothctl devices
# e.g. Device C6:E9:DF:79:01:7F ASUS Zenbook Duo Keyboard

# 3. Pair using a Python agent that displays the passkey
python3 <<'AGENT'
import dbus, dbus.service, dbus.mainloop.glib
from gi.repository import GLib

AGENT_PATH, DEVICE = "/test/agent", "C6:E9:DF:79:01:7F"  # change address

class Agent(dbus.service.Object):
    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print(f"TYPE THIS ON KEYBOARD: {passkey:06d}")
    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print(f"CONFIRMING PASSKEY: {passkey:06d}")
    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self): pass

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
agent = Agent(bus, AGENT_PATH)
mgr = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
mgr.RegisterAgent(AGENT_PATH, "DisplayYesNo")
mgr.RequestDefaultAgent(AGENT_PATH)
dev = dbus.Interface(bus.get_object("org.bluez", f"/org/bluez/hci0/dev_{DEVICE.replace(':', '_')}"), "org.bluez.Device1")
loop = GLib.MainLoop()
GLib.timeout_add(500, lambda: (dev.Pair(reply_handler=lambda: None, error_handler=print), False)[-1])
GLib.timeout_add(45000, loop.quit)
loop.run()
AGENT

# 4. Trust and connect
bluetoothctl trust C6:E9:DF:79:01:7F
bluetoothctl connect C6:E9:DF:79:01:7F
```

Type the displayed passkey on the Bluetooth keyboard and press Enter. Once paired and trusted, the device auto-reconnects on future boots.

### Why not patch bluetooth-pair.py?

Noctalia's pairing script (`/etc/xdg/quickshell/noctalia-shell/Scripts/python/src/network/bluetooth-pair.py`) uses the `KeyboardOnly` agent capability. Overriding it with `KeyboardDisplay` (to force passkey display) was attempted but the passkey still wasn't surfaced to the UI — the QML side doesn't have a widget for displaying passkeys. Until Noctalia adds passkey display support, CLI pairing is the reliable workaround.

---

## Voice-to-Text — Persistent Daemon

**Scripts:** `~/.local/bin/voice-recorder`, `~/.local/bin/voice-toggle`
**Service:** `voice-recorder.service` (systemd user unit, starts with graphical session)

A persistent daemon that records audio, transcribes via whisper-cli, and types the result into the focused window via dotoolc. Runs resident at login so all Python/GTK imports are done once — audio capture starts in ~40ms on trigger instead of ~800ms cold start.

### State machine

```
IDLE ─SIGUSR1→ RECORDING ─SIGUSR1→ TRANSCRIBING ─done→ TYPING ─done→ IDLE
```

| State | Behavior |
|-------|----------|
| IDLE | No stream, no window. Waiting for signal. |
| RECORDING | Stream open, waveform pill visible, ready tone plays on entry. |
| TRANSCRIBING | Stream closed, pill shows "Transcribing..." with pulsing dot. |
| TYPING | Window destroyed, text typed via dotoolc (clipboard fallback). |

### Trigger chain — voice-to-text

```
Physical key: BothAlts + T (LeftAlt + RightAlt + T)
  → keyd [lower+altgr] layer: t = F14
    → XKB maps F14 → XF86Launch5
      → niri keybind: XF86Launch5 → spawn-sh voice-toggle
        → voice-toggle sends SIGUSR1 to daemon PID
          → daemon toggles IDLE ↔ RECORDING
```

### Trigger chain — eDP-2 toggle (Zenbook Duo)

```
Physical key: F13 (screen-off icon on detachable keyboard)
  → XKB maps F13 → XF86Tools
    → niri keybind: XF86Tools → spawn-sh toggle-edp2
      → toggle-edp2 queries niri outputs, toggles eDP-2 on/off
```

### Services

```bash
systemctl --user enable voice-recorder.service   # auto-start on graphical login
systemctl --user start voice-recorder.service     # start now
systemctl --user status voice-recorder.service    # check status
journalctl --user -u voice-recorder -f            # follow logs
```

### Dependencies

Packages: `whisper.cpp`, `dotool`, `gtk4-layer-shell`, `python-sounddevice`, `python-numpy`, `python-gobject`
Model: `~/.local/share/whisper-models/ggml-base.en.bin` (downloaded by `arch_setup.sh`)
Runtime: `dotoold.service` must be running for typing output

---

## Maintenance

| Task | Command |
|------|---------|
| Rollback greetd | `sudo bash ~/.config/rollback-greetd.sh` |
| Reload keyd | `sudo keyd reload` |
| Validate niri config | `niri validate` |
| Niri live-reloads automatically on config save | — |
| Restart Noctalia | `systemctl --user restart noctalia` |
| Restart voice daemon | `systemctl --user restart voice-recorder` |
| Reload plugin after editing | Restart Noctalia (or use Settings > Plugins hot reload in debug mode) |
