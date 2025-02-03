#!/bin/bash

# Get the current workspace number
FOCUSED_WORKSPACE=$(/opt/homebrew/bin/aerospace list-workspaces --focused)

# Extract the workspace number from the item name
SPACE=${NAME#space.}

if [ "$SPACE" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME \
        icon.color=0xffffffff \
        background.drawing=on
else
    sketchybar --set $NAME \
        icon.color=0x99ffffff \
        background.drawing=off
fi
