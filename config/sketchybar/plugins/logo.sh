#!/bin/bash
#
# The logo menu: the handful of things Omarchy's menu offers that have a macOS
# equivalent. Everything is a one-shot action, so the rows never change -- they
# are filled once and only the popup is toggled afterwards.

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/logo.sh"

populate() {
  menu_set logo.apps       ""  "Apps öffnen…"          "$ITEM_COLOR" "$SELF run raycast"
  menu_set logo.screenshot "󰹑"  "Screenshot"            "$ITEM_COLOR" "$SELF run screenshot"
  menu_set logo.reload_bar "󰑓"  "SketchyBar neu laden"  "$ITEM_COLOR" "$SELF run reload_bar"
  menu_set logo.reload_wm  "󰑓"  "AeroSpace neu laden"   "$ITEM_COLOR" "$SELF run reload_wm"
  ARGS+=( --set logo.sep drawing=on )
  menu_set logo.settings   "󰒓"  "Systemeinstellungen…"  "$color7"     "$SELF run settings"
  menu_flush
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
"run")
  menu_close logo
  case "$2" in
    raycast)     open -a Raycast ;;
    screenshot)  screencapture -i "$HOME/Desktop/Screenshot $(date '+%Y-%m-%d %H.%M.%S').png" ;;
    reload_bar)  sketchybar --reload ;;
    reload_wm)   aerospace reload-config ;;
    settings)    open -a "System Settings" ;;
  esac
  exit 0
  ;;
esac

case "$SENDER" in
"mouse.exited.global" | "display_change")
  menu_close logo
  ;;
"mouse.clicked")
  if menu_is_open logo; then
    menu_close logo
  else
    menu_open logo
    populate
  fi
  ;;
esac
