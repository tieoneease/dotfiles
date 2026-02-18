# Desktop Environment Setup

Wayland-native tiling setup on Arch Linux.

| Component | Role |
|-----------|------|
| **Niri** | Scrollable tiling Wayland compositor |
| **Noctalia Shell** | Desktop shell (bar, launcher, notifications) — Kanagawa theme |
| **keyd** | Keyboard daemon for tap-hold and composite layers |
| **matugen** | Material Design 3 color extraction (called by Noctalia) |
| **Alacritty** | Terminal emulator |
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
│       ├── Built-in: niri, kitty, alacritty, yazi    │
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

Workspaces 1–9 are declared with `workspace "1"` through `workspace "9"`.

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
| `Mod+1-9` | Focus workspace N |
| `Mod+Ctrl+1-9` | Move column to workspace N |
| `ISO_Level3_Shift+X/C/V/S/D/F/W/E/R` | Focus workspace 1–9 (RightAlt) |
| `ISO_Level3_Shift+Shift+...` | Move column to workspace 1–9 |
| `ISO_Level3_Shift+M/Comma` | Focus next non-empty workspace up/down (skips empty) |
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
- **Terminal command:** `alacritty -e`
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

#### Walker CSS

- **Template:** `~/.config/noctalia/templates/walker-style.css`
- **Output:** `~/.config/walker/themes/noctalia/style.css`

Full GTK CSS theme for the walker launcher. Uses `* { all: unset }` then rebuilds styling with Material Design color tokens. Sets `font-family: "Sans Serif", sans-serif` and `font-size: 14px` on `.box-wrapper` so all children inherit Noto Sans at a comfortable size after the reset.

### Apps themed by Noctalia (built-in)

GTK 3/4, Qt, Niri, Kitty, Alacritty, Yazi, Foot, Ghostty, Fuzzel, Discord, Firefox

### Apps themed via user templates

Neovim, Tmux, Walker

---

## Alacritty — Terminal

**Config:** `~/.config/alacritty/alacritty.toml`

```toml
import = ["~/.config/alacritty/colors.toml"]

[[keyboard.bindings]]
key = "Return"
mods = "Shift"
chars = "\x1b\r"
```

- Colors imported from matugen-generated file
- Shift+Enter sends `ESC CR` (useful for some TUI apps)

---

## XWayland — X11 Compatibility

**Started by:** `spawn-at-startup "xwayland-satellite"` in niri config

`xwayland-satellite` provides an XWayland server for X11 applications (Steam, some games, older tools). It starts with niri and sets `DISPLAY` so X11 apps work transparently.

Without it, X11 apps fail with "Unable to open a connection to X".

---

## Gaming

**Setup:** Optional section in `arch_setup.sh` (prompted during install)

### Packages

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

## Wallpapers

**Directory:** `~/Pictures/Wallpapers/`

~395 images sourced from:

| Source | Content |
|--------|---------|
| [Gurjaka/Kanagawa-Wallpapers](https://codeberg.org/Gurjaka/Kanagawa-Wallpapers) | Kanagawa palette wallpapers |
| [dharmx/walls](https://github.com/dharmx/walls) | anime, chillop, calm, pixel, wave categories |
| [D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) | lo-fi, Japanese, mountain, city, pixel art |

Select wallpapers via Noctalia's wallpaper picker. Colors auto-apply to the shell, Niri borders, and Alacritty.

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
~/.config/
├── niri/
│   ├── config.kdl                                   # compositor config
│   └── colors.kdl                                   # auto-generated by matugen
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
├── alacritty/
│   ├── alacritty.toml                               # terminal config
│   └── colors.toml                                  # auto-generated by matugen
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

Built-in templates:
- `~/.config/niri/noctalia.kdl`
- `~/.config/kitty/themes/noctalia.conf`
- `~/.config/alacritty/themes/noctalia.toml`
- `~/.config/yazi/flavors/noctalia.yazi/`

User templates:
- `~/.config/nvim/lua/noctalia_colors.lua`
- `~/.config/tmux/colors.conf`
- `~/.config/walker/themes/noctalia/style.css`

These are overwritten every time a wallpaper is selected in Noctalia.

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

### Trigger chain

```
Physical key: LeftCtrl + V
  → keyd [custom] layer: v = F13
    → XKB maps F13 → XF86Tools
      → niri keybind: XF86Tools → spawn-sh voice-toggle
        → voice-toggle sends SIGUSR1 to daemon PID
          → daemon toggles IDLE ↔ RECORDING
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
