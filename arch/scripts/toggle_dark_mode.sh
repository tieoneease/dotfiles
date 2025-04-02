#!/usr/bin/env bash

set -euo pipefail

# Script to toggle between light and dark mode for Arch Linux with Hyprland
# This should be called from your hyprland.conf with a keybinding

# Define config files
GTK3_CONFIG="$HOME/.config/gtk-3.0/settings.ini"
GTK4_CONFIG="$HOME/.config/gtk-4.0/settings.ini"

# Function to check current theme
get_current_theme() {
    if grep -q "gtk-application-prefer-dark-theme=1" "$GTK3_CONFIG" 2>/dev/null; then
        echo "dark"
    else
        echo "light"
    fi
}

# Function to set dark mode
set_dark_mode() {
    echo "Setting dark mode..."
    
    # Set GTK3 theme
    sed -i 's/gtk-application-prefer-dark-theme=0/gtk-application-prefer-dark-theme=1/g' "$GTK3_CONFIG"
    sed -i 's/gtk-theme-name=Adwaita/gtk-theme-name=Adwaita-dark/g' "$GTK3_CONFIG"
    
    # Set GTK4 theme
    sed -i 's/gtk-application-prefer-dark-theme=0/gtk-application-prefer-dark-theme=1/g' "$GTK4_CONFIG"
    sed -i 's/gtk-theme-name=Adwaita/gtk-theme-name=Adwaita-dark/g' "$GTK4_CONFIG"
    
    # Set GNOME color scheme
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    
    # Reload Waybar with dark theme
    killall -SIGUSR2 waybar
    
    # Notify user
    notify-send "Theme Switched" "Dark mode enabled" --icon=preferences-desktop-theme
}

# Function to set light mode
set_light_mode() {
    echo "Setting light mode..."
    
    # Set GTK3 theme
    sed -i 's/gtk-application-prefer-dark-theme=1/gtk-application-prefer-dark-theme=0/g' "$GTK3_CONFIG"
    sed -i 's/gtk-theme-name=Adwaita-dark/gtk-theme-name=Adwaita/g' "$GTK3_CONFIG"
    
    # Set GTK4 theme
    sed -i 's/gtk-application-prefer-dark-theme=1/gtk-application-prefer-dark-theme=0/g' "$GTK4_CONFIG"
    sed -i 's/gtk-theme-name=Adwaita-dark/gtk-theme-name=Adwaita/g' "$GTK4_CONFIG"
    
    # Set GNOME color scheme
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    
    # Reload Waybar with light theme
    killall -SIGUSR2 waybar
    
    # Notify user
    notify-send "Theme Switched" "Light mode enabled" --icon=preferences-desktop-theme
}

# Main function
main() {
    current_theme=$(get_current_theme)
    
    if [ "$current_theme" = "dark" ]; then
        set_light_mode
    else
        set_dark_mode
    fi
}

# Execute main function
main "$@"