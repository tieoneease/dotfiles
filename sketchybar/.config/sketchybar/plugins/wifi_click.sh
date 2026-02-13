#!/bin/bash

# Get Wi-Fi info
WIFI_DEVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
CURRENT_WIFI=$(networksetup -getairportnetwork $WIFI_DEVICE | awk -F": " '{print $2}')
WIFI_POWER=$(networksetup -getairportpower $WIFI_DEVICE | awk '{print $4}')

# Create popup item if it doesn't exist
sketchybar --add item wifi.ssid popup.wifi \
          --set wifi.ssid \
          icon="" \
          icon.padding_left=10 \
          label.padding_right=10 \
          background.padding_left=5 \
          background.padding_right=5

# Update popup content
if [ "$WIFI_POWER" = "Off" ]; then
    sketchybar --set wifi.ssid label="WiFi: Off"
elif [ "$CURRENT_WIFI" = "off" ] || [ -z "$CURRENT_WIFI" ]; then
    sketchybar --set wifi.ssid label="Not Connected"
else
    sketchybar --set wifi.ssid label="$CURRENT_WIFI"
fi

# Toggle the popup
sketchybar --set wifi popup.drawing=toggle
