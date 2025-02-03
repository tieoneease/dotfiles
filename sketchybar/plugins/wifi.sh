#!/bin/bash

# Get Wi-Fi info using networksetup
WIFI_DEVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
WIFI_POWER=$(networksetup -getairportpower $WIFI_DEVICE | awk '{print $4}')

if [ "$WIFI_POWER" = "Off" ]; then
    sketchybar --set wifi icon="󰖪" label=""
    exit 0
fi

# Get current Wi-Fi connection info
CURRENT_WIFI=$(networksetup -getairportnetwork $WIFI_DEVICE | awk -F": " '{print $2}')

if [ "$CURRENT_WIFI" = "off" ] || [ -z "$CURRENT_WIFI" ]; then
    sketchybar --set wifi icon="󰖪" label=""
else
    sketchybar --set wifi icon="󰖩" label=""
fi
