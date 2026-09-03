#!/bin/bash
#
# Omarchy's leftmost button (custom/omarchy -> omarchy-menu). Its own glyph
# font does not exist here, so this uses the Nerd Font Apple mark.

menu_item logo left left
ARGS+=( --set logo "icon=$ICON_LOGO" "icon.color=$ACCENT_COLOR" label.drawing=off )

menu_row       logo logo.apps
menu_row       logo logo.screenshot
menu_row       logo logo.reload_bar
menu_row       logo logo.reload_wm
menu_separator logo logo.sep
menu_row       logo logo.settings

menu_flush

"$PLUGIN_DIR/logo.sh" populate &
