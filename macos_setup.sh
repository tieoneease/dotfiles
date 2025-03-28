#!/usr/bin/env bash

set -euo pipefail

echo "Setting up macOS-specific configurations..."

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install applications via Homebrew
echo "Installing applications via Homebrew..."

# Install kitty terminal
echo "Installing kitty terminal..."
brew install --cask kitty

# Install neovim
echo "Installing neovim..."
brew install neovim

# Install tmux
echo "Installing tmux..."
brew install tmux

# Install tmux-sessionizer
echo "Installing tmux-sessionizer..."
brew install fzf
mkdir -p ~/.local/bin
curl -o ~/.local/bin/tmux-sessionizer https://raw.githubusercontent.com/ThePrimeagen/tmux-sessionizer/master/tmux-sessionizer
chmod +x ~/.local/bin/tmux-sessionizer
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# Install nvm (Node Version Manager)
echo "Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Install uv (Python package manager)
echo "Installing uv..."
brew install uv

# Install fontconfig
echo "Installing fontconfig..."
brew install fontconfig

# Install Nerd Fonts
echo "Installing Nerd Fonts..."
brew install font-hack-nerd-font font-inconsolata-go-nerd-font font-jetbrains-mono-nerd-font \
    font-meslo-lg-nerd-font font-fira-code-nerd-font font-sauce-code-pro-nerd-font \
    font-roboto-mono-nerd-font font-ubuntu-mono-nerd-font font-droid-sans-mono-nerd-font \
    font-inconsolata-nerd-font font-inconsolata-lgc-nerd-font

# Refresh font cache
echo "Refreshing font cache..."
fc-cache -f -v

# Install karabiner-elements
echo "Installing karabiner-elements..."
brew install --cask karabiner-elements

# Add aerospace tap and install
echo "Adding aerospace tap..."
brew tap nikitabobko/tap
brew install --cask nikitabobko/tap/aerospace

# Install Sketchybar
echo "Installing Sketchybar..."
brew tap FelixKratz/formulae
brew install sketchybar

# Create Sketchybar config directory
mkdir -p ~/.config/sketchybar

# Start Sketchybar
brew services start felixkratz/formulae/sketchybar

# Configure menu bar to auto-hide
defaults write NSGlobalDomain _HIHideMenuBar -bool false
defaults write NSGlobalDomain AppleMenuBarVisibleOnAllDisplays -bool true

# Enable menu bar auto-hide in System Settings programmatically
osascript -e 'tell application "System Settings"
    activate
    delay 1
    tell application "System Events"
        select menu item "Control Centre" of menu "View" of menu bar 1
        delay 1
        click checkbox "Automatically hide and show the menu bar" of window 1
    end tell
    quit
end tell'

# Configure key repeat rate and delay
echo "Configuring keyboard settings..."
# Set key repeat rate (lower number is faster, default is 2)
defaults write -g KeyRepeat -int 1
# Set delay until repeat (lower number is shorter delay, default is 15)
defaults write -g InitialKeyRepeat -int 10

# Enable key repeat for all applications (including VS Code and others)
defaults write -g ApplePressAndHoldEnabled -bool false

# Set window animation speed to be nearly instant
defaults write -g NSWindowResizeTime -float 0.001

# Kill affected applications
echo "Restarting affected applications..."
for app in "Finder" "SystemUIServer"; do
    killall "${app}" &> /dev/null
done

echo "macOS setup completed! Please log out and back in for all changes to take effect."
echo "Note: You may need to add kitty.app to System Settings > Privacy & Security > Full Disk Access"
