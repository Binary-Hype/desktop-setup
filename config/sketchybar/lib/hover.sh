#!/bin/bash
#
# Hover highlight for every menu row. Rows point their `script` here, so no
# module has to carry a mouse.entered/exited branch of its own.
source "$CONFIG_DIR/lib/common.sh"

case "$SENDER" in
  "mouse.entered")
    sketchybar --set "$NAME" background.color="$ITEM_BG_COLOR"
    ;;
  "mouse.exited" | "mouse.exited.global")
    sketchybar --set "$NAME" background.color="$MENU_ROW_BG_IDLE"
    ;;
esac
