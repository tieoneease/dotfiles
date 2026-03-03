# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Covers EndeavourOS / CachyOS (Niri + Noctalia Shell), macOS (Aerospace), and headless VPS environments.

## Quick Start

```bash
git clone git@github.com:tieoneease/dotfiles.git ~/dotfiles
cd ~/dotfiles
just setup   # auto-detects platform
```

`just setup` detects the platform and runs the appropriate setup script:

| Platform | Script | What it does |
|----------|--------|--------------|
| Arch / EndeavourOS / CachyOS | `arch_setup.sh` | yay packages, keyd, greetd, Noctalia patches, stow, pi setup |
| macOS | `macos_setup.sh` | Homebrew packages, stow, pi setup |
| Linux (headless) | `vps_setup.sh` | Minimal dev tooling, stow (`--vps` subset) |

All setup scripts are **idempotent** — safe to re-run at any time.

### Other commands

```bash
just stow             # re-symlink all dotfiles
just pi               # set up pi coding agent (extensions, subagent, agents)
just patch-noctalia   # re-apply Noctalia QML patches (Arch, needs sudo)
just fonts            # refresh font cache
```

## Architecture (EndeavourOS)

| Component | Role |
|-----------|------|
| **Niri** | Scrollable tiling Wayland compositor |
| **Noctalia Shell** | Desktop shell — bar, launcher, notifications, Material Design 3 theming |
| **keyd** | Keyboard daemon — tap-hold numpad, tab nav, arrow layers |
| **greetd + tuigreet** | Login greeter → launches niri-session |
| **Kitty** | Terminal emulator |
| **Neovim** | Editor (base16-nvim for dynamic theming) |
| **Tmux** | Terminal multiplexer with tmux-sessionizer |
| **Zsh + Starship** | Shell with prompt |
| **swayidle + swaylock** | Screen lock on idle / before suspend |
| **xwayland-satellite** | XWayland server for X11 apps (Steam, etc.) |

See [NIRI-SETUP.md](NIRI-SETUP.md) for detailed architecture documentation.

## Stow Structure

Each package mirrors `$HOME`. Stow creates symlinks from `~/` into the repo:

```
dotfiles/
├── Core
│   ├── zsh/           .zshenv, .config/zsh/{base,aliases}.zsh
│   ├── starship/      .config/starship.toml
│   ├── kitty/         .config/kitty/
│   ├── nvim/          .config/nvim/
│   ├── tmux/          .config/tmux/
│   ├── tms/           .config/tms/            (tmux-sessionizer)
│   ├── direnv/        .config/direnv/
│   ├── mise/          .config/mise/           (polyglot version manager)
│   ├── nix/           .config/nix/
│   ├── ssh/           .ssh/config
│   └── fontconfig/    .config/fontconfig/
│
├── Desktop (Linux)
│   ├── niri/          .config/niri/           (compositor config, scripts)
│   ├── noctalia/      .config/noctalia/       (shell settings, templates, plugins)
│   ├── gtk/           .config/gtk-{3,4}.0/    (GTK theming)
│   ├── walker/        .config/walker/         (app launcher)
│   ├── yazi/          .config/yazi/           (file manager)
│   ├── zathura/       .config/zathura/        (PDF viewer)
│   ├── fcitx5/        .config/fcitx5/, .local/share/fcitx5/rime/ (input method)
│   ├── webapps/       chromium flags, webapp-launch/install scripts, .desktop files
│   ├── pencil/        .desktop + icon for Pencil (stowed with --no-folding)
│   ├── voice/         .local/bin/voice-recorder, voice-toggle
│   ├── vdirsyncer/    systemd timer + setup script for Google Calendar sync
│   ├── pipewire/      PipeWire Pulse config (block source volume changes)
│   └── wireplumber/   WirePlumber config (no-suspend for audio devices)
│
├── Desktop (macOS)
│   ├── aerospace/     .config/aerospace/      (tiling WM)
│   ├── sketchybar/    .config/sketchybar/     (status bar)
│   └── karabiner/     .config/karabiner/      (keyboard remapping)
│
├── Claude Code
│   ├── claude/        .claude/settings.json
│   └── claude-memory/ MEMORY.md + topic files (Claude Code project memories)
│
├── System configs (copied, not stowed)
│   ├── etc/           keyd, greetd, systemd, udev, modprobe, libinput, bluetooth
│   └── wallpapers/    default wallpapers → ~/Pictures/Wallpapers/
│
├── Build / patches
│   ├── niri-git/      PKGBUILD + cached packages for niri-git
│   └── patches/       Noctalia QML patch files
│
├── Setup
│   ├── justfile       task runner (just setup, just stow, etc.)
│   ├── arch_setup.sh  full EndeavourOS/Arch setup
│   ├── macos_setup.sh full macOS setup
│   ├── vps_setup.sh   headless server setup
│   ├── pi_setup.sh    pi coding agent setup
│   ├── patch_noctalia.sh  Noctalia QML patches (idempotent)
│   ├── setup.sh       legacy dispatcher (use justfile instead)
│   ├── setup/         common.sh (shared helper functions)
│   └── stow/          stow_dotfiles.sh
│
└── secrets/           env.example (template for .env secrets)
```

## Theming (Material Design 3)

Dynamic colors generated from the current wallpaper via Noctalia Shell + matugen:

1. **Noctalia built-in templates** generate configs for niri, kitty, yazi, walker, and fuzzel
2. **Custom user templates** (`noctalia/.config/noctalia/templates/`) generate configs for nvim, tmux
3. **GTK theming** via Noctalia's template processor → `gtk-3.0/noctalia.css`, `gtk-4.0/noctalia.css`

All generated color files are gitignored — they're recreated on each wallpaper change.

## Noctalia Plugins

Local plugins in `noctalia/.config/noctalia/plugins/`:

| Plugin | Description |
|--------|-------------|
| **sleep-inhibitor** | Blocks suspend/hibernate while allowing screen blanking. Coffee icon in bar. |
| **screen-toggle** | Toggles secondary screen on Zenbook Duo. Self-hides when hardware not detected. |
| **lte-status** | LTE modem status indicator. |

## Zsh Configuration

Layered to keep the repo clean while allowing installer additions:

- **`~/.zshenv`** (tracked) — Nix, NVM, Cargo env setup
- **`~/.config/zsh/base.zsh`** (tracked) — history, completion, plugins, starship, direnv
- **`~/.config/zsh/aliases.zsh`** (tracked) — all aliases
- **`~/.config/zsh/local.zsh`** (gitignored) — machine-specific overrides
- **`~/.zshrc`** (NOT tracked) — generated by setup script; sources base.zsh; installers append here

## SSH from Kitty

Kitty sets `TERM=xterm-kitty`, which most remote hosts don't have in their terminfo database. The `ssh` alias in `aliases.zsh` automatically uses `kitten ssh` when running inside Kitty, which copies the terminfo to the remote host on first connect.

## Pi Coding Agent

Extensions, skills, prompt templates, and agent definitions live in a separate private repo ([tieoneease/pi-extensions](https://github.com/tieoneease/pi-extensions)). `pi_setup.sh` clones it, installs the package, and deploys agents.

## Nix + direnv

Nix and nix-direnv are installed automatically by `arch_setup.sh`. For projects using Nix flakes, add a `.envrc` with `use flake` and run `direnv allow`.

## License

MIT
