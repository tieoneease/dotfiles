#!/bin/bash

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o "[0-9]\+%" | tr -d '%')
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

if [ $PERCENTAGE = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="󰁹" # Full battery
  ;;
  [6-8][0-9]) ICON="󰂁" # 3/4 battery
  ;;
  [3-5][0-9]) ICON="󰁾" # 1/2 battery
  ;;
  [1-2][0-9]) ICON="󰁻" # 1/4 battery
  ;;
  *) ICON="󰂎" # Empty battery
esac

if [[ $CHARGING != "" ]]; then
  ICON="󰂄" # Lightning bolt
fi

sketchybar --set battery icon="$ICON" icon.padding_right=6 label="${PERCENTAGE}%"
