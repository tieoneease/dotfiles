#!/usr/bin/env bash

# Script to handle network management
# This script prioritizes different network tools in this order:
# 1. nm-connection-editor (if installed)
# 2. nmtui (if installed)
# 3. wofi-wifi-menu (if installed) 

# Check for network management tools
if command -v nm-connection-editor >/dev/null 2>&1; then
    nm-connection-editor
elif command -v nmtui >/dev/null 2>&1; then
    foot -e nmtui
elif command -v wofi >/dev/null 2>&1; then
    # Create a basic wofi-based network selector
    wifi_list=$(nmcli -g SSID device wifi list | sort -u)
    selected_wifi=$(echo -e "$wifi_list\n---\nRescan Networks\n---\nManual Connection\n---\nEnable Wi-Fi\nDisable Wi-Fi" | wofi --dmenu --prompt="Select WiFi Network" --width=250 --height=500 --cache-file=/dev/null)

    case "$selected_wifi" in
        "Rescan Networks")
            nmcli device wifi rescan
            ;;
        "Manual Connection")
            ssid=$(wofi --dmenu --prompt="Enter SSID" --width=250 --height=100 --cache-file=/dev/null)
            if [ -n "$ssid" ]; then
                password=$(wofi --dmenu --prompt="Enter Password" --password --width=250 --height=100 --cache-file=/dev/null)
                if [ -n "$password" ]; then
                    nmcli device wifi connect "$ssid" password "$password"
                else
                    nmcli device wifi connect "$ssid"
                fi
            fi
            ;;
        "Enable Wi-Fi")
            nmcli radio wifi on
            ;;
        "Disable Wi-Fi")
            nmcli radio wifi off
            ;;
        ---)
            # Do nothing for separator
            ;;
        "")
            # Do nothing if canceled
            ;;
        *)
            # Connect to the selected network
            if nmcli -g NAME connection show | grep -q "^$selected_wifi$"; then
                # Connect to known network
                nmcli connection up "$selected_wifi"
            else
                # Connect to new network
                password=$(wofi --dmenu --prompt="Enter Password for $selected_wifi" --password --width=350 --height=100 --cache-file=/dev/null)
                if [ -n "$password" ]; then
                    nmcli device wifi connect "$selected_wifi" password "$password"
                else
                    nmcli device wifi connect "$selected_wifi"
                fi
            fi
            ;;
    esac
else
    # Fallback to basic nmcli in terminal
    foot -e sh -c "echo 'No network management GUI found. Using nmcli directly.' && echo 'Available networks:' && nmcli device wifi list && echo '\nPress any key to exit.' && read -n 1"
fi
