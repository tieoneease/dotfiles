#!/bin/bash

# Get Wi-Fi info using networksetup
WIFI_DEVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
WIFI_POWER=$(networksetup -getairportpower $WIFI_DEVICE | awk '{print $4}')

if [ "$WIFI_POWER" = "Off" ]; then
    sketchybar --set wifi icon="󰖪" label=""
    exit 0
fi

# Check Wi-Fi connection using more reliable methods
# Try multiple methods to determine if Wi-Fi is connected

# Method 1: Use ifconfig to check if interface has an IP
WIFI_IP=$(ifconfig $WIFI_DEVICE 2>/dev/null | grep "inet " | awk '{print $2}')

# Method 2: Try airport command if available
if command -v airport &> /dev/null; then
    AIRPORT_INFO=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)
    SSID=$(echo "$AIRPORT_INFO" | awk -F': ' '/ SSID/ {print $2}')
elif [ -f "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" ]; then
    AIRPORT_INFO=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)
    SSID=$(echo "$AIRPORT_INFO" | awk -F': ' '/ SSID/ {print $2}')
fi

# Check if we have either an IP address or an SSID
if [ -n "$WIFI_IP" ] || [ -n "$SSID" ]; then
    sketchybar --set wifi icon="󰖩" label=""
else
    sketchybar --set wifi icon="󰖪" label=""
fi
