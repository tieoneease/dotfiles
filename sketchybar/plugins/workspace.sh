#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/workspace.sh

WORKSPACE_ID="$1"

# Get current workspace from aerospace directly if $FOCUSED_WORKSPACE is empty
if [ -z "$FOCUSED_WORKSPACE" ]; then
    CURRENT_WORKSPACE=$(aerospace get -space-current)
else
    CURRENT_WORKSPACE="$FOCUSED_WORKSPACE"
fi

if [ "$WORKSPACE_ID" = "$CURRENT_WORKSPACE" ]; then
    sketchybar --set "$NAME" \
        icon.color=0xffffffff \
        background.color=0x44ffffff \
        background.drawing=on
else
    sketchybar --set "$NAME" \
        icon.color=0x99ffffff \
        background.drawing=off
fi
