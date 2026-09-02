#!/bin/bash

# Source Colors
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi

# Source Layout Variables
source "$CONFIG_DIR/variables.sh"

case "$SENDER" in
"mouse.clicked")
  sketchybar --set $NAME popup.drawing=toggle
  # open -a Calendar
  ;;
*)
  sketchybar --set $NAME label="$(date +'%H:%M')"
  ;;
esac
