#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/workspace.sh

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME \
        icon.color=0xffffffff \
        background.color=0x44ffffff \
        background.drawing=on
else
    sketchybar --set $NAME \
        icon.color=0x99ffffff \
        background.drawing=off
fi
