# Waybar Configuration

A modern, minimal status bar configuration for Hyprland using Waybar.

## Features

- Clean, minimal design with semi-transparent background
- Workspace indicators with numbers
- Centered clock (click to toggle date/time)
- System indicators for:
  - Network status (clickable)
  - Volume control (clickable)
  - Battery status with charging indication
- Modern animations and hover effects
- JetBrains Mono Nerd Font icons

## Dependencies

Required packages:
- `waybar` - The status bar itself
- `ttf-jetbrains-mono-nerd` - Font for icons
- `networkmanager` - For network management
- `pavucontrol` - For volume control
- `networkmanager-dmenu` - For network menu (optional)

## Installation

### Automatic Installation

Run the included installation script:
```bash
chmod +x install.sh
./install.sh
```

### Manual Installation

1. Install required packages:
```bash
sudo pacman -S waybar ttf-jetbrains-mono-nerd pavucontrol
```

2. Install optional packages:
```bash
sudo pacman -S networkmanager-dmenu-git
```

3. Ensure Waybar is configured to start with Hyprland:
```bash
# Add to your hyprland.conf
exec-once = waybar
```

## Usage

- Click workspace numbers to switch between them
- Click the clock to toggle between time and date
- Click volume icon to open volume control
- Click network icon to open network settings
- Hover over icons for detailed information

## Customization

- Edit `config.jsonc` to modify modules and their behavior
- Edit `style.css` to change the visual appearance

## Troubleshooting

If Waybar doesn't start:
1. Check if Waybar is installed: `which waybar`
2. Check Waybar status: `waybar -l debug`
3. Verify font installation: `fc-list | grep "JetBrains"`
