#!/bin/bash

echo "Setting up macOS-specific configurations..."

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install applications via Homebrew
echo "Installing applications via Homebrew..."
brew install --cask kitty

# Add aerospace tap and install
echo "Adding aerospace tap..."
brew tap nikitabobko/tap
brew install --cask nikitabobko/tap/aerospace

# Configure key repeat rate and delay
echo "Configuring keyboard settings..."
# Set key repeat rate (lower number is faster, default is 2)
defaults write -g KeyRepeat -int 1
# Set delay until repeat (lower number is shorter delay, default is 15)
defaults write -g InitialKeyRepeat -int 10

# Enable key repeat for all applications (including VS Code and others)
defaults write -g ApplePressAndHoldEnabled -bool false

# Kill affected applications
echo "Restarting affected applications..."
for app in "Finder" "SystemUIServer"; do
    killall "${app}" &> /dev/null
done

echo "macOS setup completed! Please log out and back in for all changes to take effect."
echo "Note: You may need to add kitty.app to System Settings > Privacy & Security > Full Disk Access"
