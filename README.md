# Dotfiles

My personal dotfiles, managed with GNU Stow.

## Quick Setup

1. Clone the repository:
```bash
git clone git@github.com:tieoneease/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Run the macOS setup script (if on macOS):
```bash
./macos_setup.sh
```

3. Stow the dotfiles:
```bash
./stow/stow_dotfiles.sh
```

4. Log out and log back in for all changes to take effect.

After logging back in:
- All your configured tools (starship, tmux, etc.) will be available
- Your configuration files will be properly symlinked from ~/.config

## Project Structure

```
dotfiles/
├── macos_setup.sh        # macOS setup script
├── stow/
│   └── stow_dotfiles.sh  # Stow script for symlinking configs
├── direnv/               # direnv + nix-direnv configuration
├── kitty/                # Terminal configuration
├── nix/                  # Nix configuration
├── nvim/                 # Neovim configuration
├── tmux/                 # Tmux configuration
├── zsh/                  # Zsh configuration
├── karabiner/            # Karabiner configuration
├── sketchybar/           # Status bar for macOS
├── starship/             # Starship prompt configuration
└── wallpapers/           # Wallpapers
```

## Nix + direnv Setup

For projects using Nix flakes, install nix-direnv for cached environments:

```bash
nix profile install nixpkgs#nix-direnv
```

This caches Nix flake evaluations, making `direnv` loads instant after the first build.

## Configuration Management

This repository uses GNU Stow for configuration management:

- **GNU Stow**: Creates symlinks from your home directory to files in the dotfiles repo

### Making Changes

To modify configurations:

1. Edit the relevant files in the repository
2. The changes will be automatically applied (since they're symlinked)
3. Commit and push your changes

## Components

The following tools are configured and managed by this setup:

- **Shell**: Zsh with Starship prompt
- **Terminal Multiplexer**: Tmux with custom configuration
- **Editor**: Neovim
- **Terminal**: Kitty
- **macOS Tools**: 
  - Sketchybar (status bar)
  - Karabiner-Elements (keyboard customization)
  - Aerospace (window manager)
- **CLI Tools**:
  - Nix with flakes
  - direnv + nix-direnv (cached dev environments)
  - NVM (Node Version Manager)
  - UV (Python package manager)
  - FZF (Fuzzy finder)
  - tmux-sessionizer (session management)

## License

MIT
