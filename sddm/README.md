# SDDM Configuration

This directory contains the configuration for SDDM (Simple Desktop Display Manager), the login manager.

## Theme: Sugar Candy

Using the Sugar Candy theme for a modern, clean login experience. The theme features:
- Blurred background
- Modern rounded corners
- Clean typography using JetBrains Mono
- Smooth animations
- Professional color scheme

## Files
- `theme.conf`: Configuration for the Sugar Candy theme
- `install.sh`: Installation script
- `faillock.conf`: Login attempt configuration

## Installation

1. Install required packages:
```bash
paru -S sddm-theme-sugar-candy-git
```

2. Run the installation script:
```bash
cd ~/dotfiles/sddm
./install.sh
```

## Customization

You can customize the login screen by modifying `theme.conf`. Available options include:
- Background image
- Color scheme
- Font settings
- Corner radius
- Screen padding
