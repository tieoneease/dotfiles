# Desktop Environment Setup

Wayland-native tiling setup on Arch Linux.

| Component | Role |
|-----------|------|
| **Niri** | Scrollable tiling Wayland compositor |
| **Noctalia Shell** | Desktop shell (bar, launcher, notifications) — Kanagawa theme |
| **keyd** | Keyboard daemon for tap-hold and composite layers |
| **matugen** | Material Design 3 color extraction (called by Noctalia) |
| **Alacritty** | Terminal emulator |
| **Fuzzel** | Application launcher (backup; Noctalia has built-in) |
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
│  └── includes colors.kdl (auto-generated)           │
├─────────────────────────────────────────────────────┤
│ keyd (system-level, /etc/keyd/default.conf)         │
│  ├── LeftAlt tap-hold → numpad layer                │
│  ├── RightAlt tap-hold → nav layer (tab mgmt)       │
│  ├── Both Alts → arrows + Home/End/PgUp/PgDn        │
│  └── RightCtrl tap-hold → control (vol/brightness)  │
├─────────────────────────────────────────────────────┤
│ Noctalia Shell (systemd user service)               │
│  ├── Kanagawa color scheme                          │
│  ├── useWallpaperColors: true                       │
│  └── Calls matugen → generates color templates      │
│       ├── ~/.config/niri/colors.kdl                 │
│       └── ~/.config/alacritty/colors.toml           │
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

#### `[numpad:A]` — LeftAlt held

Tap LeftAlt = LeftAlt. Hold LeftAlt + key = numpad digit.

The `:A` suffix means unmapped keys pass through with Alt — so `Alt+H/J/K/L` (niri focus) still works.

```
w e r         →  7 8 9
s d f         →  4 5 6
x c v b       →  1 2 3 0
```

`[numpad+shift]` maps the same keys to `Shift+digit` (i.e. `!@#` etc.).

#### `[nav:G]` — RightAlt held (Chrome tab management)

Tap RightAlt = RightAlt. Hold RightAlt + key = tab action.

The `:G` (AltGr) suffix means unmapped keys pass through as ISO_Level3_Shift — so niri's `RightAlt+X/C/V` workspace binds still work.

| Key | Sends | Action |
|-----|-------|--------|
| `h` | Ctrl+Shift+PageUp | Move tab left |
| `j` | Ctrl+Shift+Tab | Previous tab |
| `k` | Ctrl+Tab | Next tab |
| `l` | Ctrl+Shift+PageDown | Move tab right |

#### `[numpad+nav]` — Both Alts held (arrows and navigation)

This is a composite layer that activates when both LeftAlt and RightAlt are held simultaneously. It **must** appear after both constituent layers in the config file.

| Key | Output |
|-----|--------|
| `h` | Left |
| `j` | Down |
| `k` | Up |
| `l` | Right |
| `n` | Home |
| `m` | PageDown |
| `,` | PageUp |
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
| `Alt+Space` | Fuzzel launcher |
| `Super+B` | Chrome |
| `Super+Alt+L` | Lock (swaylock) |
| `Mod+Q` | Close window |
| `Alt+H/J/K/L` | Focus left/down/up/right |
| `Alt+Shift+H/J/K/L` | Move window left/down/up/right |
| `Mod+1-9` | Focus workspace N |
| `Mod+Ctrl+1-9` | Move column to workspace N |
| `ISO_Level3_Shift+X/C/V/S/D/F/W/E/R` | Focus workspace 1–9 (RightAlt) |
| `ISO_Level3_Shift+Shift+...` | Move column to workspace 1–9 |
| `ISO_Level3_Shift+M/Comma` | Focus workspace up/down |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+W` | Toggle tabbed column |
| `Mod+R` | Cycle preset widths |
| `Print` | Screenshot |

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

#### Niri border colors

- **Template:** `~/.config/noctalia/templates/niri-colors.kdl`
- **Output:** `~/.config/niri/colors.kdl`
- **Post-hook:** `niri msg action load-config-file`

Sets focus-ring, border, and shadow colors using `primary`, `surface_variant`, and `shadow` Material Design tokens.

#### Alacritty colors

- **Template:** `~/.config/noctalia/templates/alacritty-colors.toml`
- **Output:** `~/.config/alacritty/colors.toml`

Maps terminal ANSI colors to Material Design tokens:

| ANSI color | Material token |
|------------|----------------|
| background | `surface` |
| foreground | `on_surface` |
| red | `error` |
| green, blue | `primary` |
| yellow, magenta | `tertiary` |
| cyan | `secondary` |

### Apps themed by Noctalia (built-in)

GTK 3/4, Qt, Kitty, Foot, Ghostty, Fuzzel, Discord, Firefox

### Apps themed via user templates

Niri (focus-ring/border), Alacritty

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
│   │   ├── niri-colors.kdl                          # niri color template
│   │   └── alacritty-colors.toml                    # alacritty color template
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
├── rollback-greetd.sh                               # greetd rollback script
~/Pictures/
└── Wallpapers/                                      # ~395 wallpapers
```

### Auto-generated files (do not edit)

- `~/.config/niri/colors.kdl`
- `~/.config/alacritty/colors.toml`

These are overwritten every time a wallpaper is selected in Noctalia.

---

## Maintenance

| Task | Command |
|------|---------|
| Rollback greetd | `sudo bash ~/.config/rollback-greetd.sh` |
| Reload keyd | `sudo keyd reload` |
| Validate niri config | `niri validate` |
| Niri live-reloads automatically on config save | — |
| Restart Noctalia | `systemctl --user restart noctalia` |
| Reload plugin after editing | Restart Noctalia (or use Settings > Plugins hot reload in debug mode) |
