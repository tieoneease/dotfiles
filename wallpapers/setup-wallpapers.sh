#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

WALLPAPERS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Array of wallpaper URLs (minimalist lo-fi cyberpunk themed)
declare -a WALLPAPER_URLS=(
    "https://w.wallhaven.cc/full/7p/wallhaven-7p97ld.png"  # Minimalist cyberpunk city
    "https://w.wallhaven.cc/full/rd/wallhaven-rdwjj7.jpg"  # Lo-fi room with neon
    "https://w.wallhaven.cc/full/x8/wallhaven-x8ye3z.png"  # Minimal cyber aesthetic
    "https://w.wallhaven.cc/full/6o/wallhaven-6ox118.png"  # Abstract minimal cyberpunk
)

echo -e "${BLUE}Setting up wallpapers...${NC}"

# Install dependencies if needed
if ! command -v curl &> /dev/null; then
    echo -e "${BLUE}Installing curl...${NC}"
    sudo pacman -S --noconfirm curl
fi

if ! command -v hyprpaper &> /dev/null; then
    echo -e "${BLUE}Installing hyprpaper...${NC}"
    sudo pacman -S --noconfirm hyprpaper
fi

# Download wallpapers
for url in "${WALLPAPER_URLS[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "$WALLPAPERS_DIR/$filename" ]; then
        echo -e "${BLUE}Downloading wallpaper: $filename${NC}"
        curl -o "$WALLPAPERS_DIR/$filename" "$url"
    fi
done

# Create hyprpaper configuration
cat > "$WALLPAPERS_DIR/../hypr/hyprpaper.conf" << EOL
preload = $WALLPAPERS_DIR/wallhaven-7p97ld.png
preload = $WALLPAPERS_DIR/wallhaven-rdwjj7.jpg
preload = $WALLPAPERS_DIR/wallhaven-x8ye3z.png
preload = $WALLPAPERS_DIR/wallhaven-6ox118.png

# Set default wallpaper
wallpaper = eDP-1,$WALLPAPERS_DIR/wallhaven-7p97ld.png
EOL

# Make sure hyprpaper is started with Hyprland
if ! grep -q "^exec-once = hyprpaper" "$WALLPAPERS_DIR/../hypr/hyprland.conf"; then
    echo -e "${BLUE}Adding hyprpaper to Hyprland autostart...${NC}"
    echo "exec-once = hyprpaper" >> "$WALLPAPERS_DIR/../hypr/hyprland.conf"
fi

echo -e "${GREEN}Wallpaper setup complete!${NC}"
echo -e "${BLUE}To change wallpaper, edit hypr/hyprpaper.conf and choose from:${NC}"
for url in "${WALLPAPER_URLS[@]}"; do
    echo "- $(basename "$url")"
done
echo -e "${BLUE}Then restart Hyprland or run: hyprctl hyprpaper preload <path> && hyprctl hyprpaper wallpaper \"eDP-1,<path>\"${NC}"
