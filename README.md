# Dotfiles

My personal dotfiles, now managed with Nix Home Manager and GNU Stow.

## Quick Setup

1. Clone the repository:
```bash
git clone git@github.com:tieoneease/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Run the bootstrap script:
```bash
./bootstrap.sh
```

3. Log out and log back in for all changes to take effect.

After logging back in:
- You'll be in zsh by default (if you changed your shell)
- Home Manager's configuration will be loaded automatically
- All your configured tools (starship, tmux, etc.) will be available

## Project Structure

```
dotfiles/
├── bootstrap.sh          # Main setup script
└── nix/                  # Nix configuration
    ├── setup.sh         # Nix-specific setup
    └── .config/         # Stow-managed config directory
        ├── nix/
        │   └── nix.conf
        └── home-manager/
            ├── flake.nix
            └── home.nix
```

## Configuration Management

This repository uses two main tools for configuration management:

1. **GNU Stow**: Manages symlinks for configuration files
2. **Home Manager**: Manages packages and their configurations through Nix

### Making Changes

To modify configurations:

1. Edit the relevant files in the repository
2. Run `home-manager switch` to apply changes
3. Commit and push your changes

## Updating Configuration

To update your configuration after making changes:

```bash
# Apply home-manager changes
home-manager switch

# Or run the setup script again
./nix/setup.sh
```

## Components

The following tools are configured and managed by this setup:

- **Shell**: zsh with custom configuration
- **Terminal Multiplexer**: tmux with Vim-like keybindings and Catppuccin theme
- **Editor**: Neovim
- **Terminal**: Kitty
- **Window Manager**: Hyprland with Waybar
- **Prompt**: Starship

## License

MIT
