#!/bin/bash
#
# Geometry, fonts and menu metrics. Values mirror Omarchy's Waybar
# (basecamp/omarchy: config/waybar/config.jsonc + style.css) so the bar reads
# the same on macOS; the Waybar rule each one comes from is noted inline.
#
# Colours live in colors.sh -- deliberately separate, because
# ~/.config/borders/bordersrc sources that file too.

# --- Bar Appearance -----------------------------------------------------------
# Omarchy's bar is flat and full width: "height": 26, no margin, no radius,
# `border: none`. Nothing floats, so there is no y_offset and no blur.
export BAR_HEIGHT=26
export BAR_Y_OFFSET=0
export BAR_BLUR_RADIUS=0
export BAR_POSITION="top"
export BAR_STICKY="off"
# "window" keeps the bar drawn above app windows so a maximised or moved window
# can never paint over it. AeroSpace gaps (outer.top) do the real spacing.
export BAR_TOPMOST="window"
export BAR_MARGIN=0
export BAR_CORNER_RADIUS=0
export BAR_BORDER_WIDTH=0
# .modules-left { margin-left: 8px } / .modules-right { margin-right: 8px }
export BAR_PADDING_LEFT=8
export BAR_PADDING_RIGHT=8

# --- Item Defaults ------------------------------------------------------------
export ITEM_UPDATES="when_shown"
# #cpu, #battery, #pulseaudio { margin: 0 7.5px }
export ITEM_PADDING_LEFT=7
export ITEM_PADDING_RIGHT=7

# --- Fonts --------------------------------------------------------------------
# font-family: 'JetBrainsMono Nerd Font'; font-size: 12px -- 13pt matches that
# optically at macOS' point scale.
export ICON_FONT="JetBrainsMono Nerd Font:Regular:13.0"
export LABEL_FONT="JetBrainsMono Nerd Font:Regular:13.0"
export ICON_PADDING_LEFT=0
export ICON_PADDING_RIGHT=0
export ICON_DRAWING="on"
export LABEL_PADDING_LEFT=0
export LABEL_PADDING_RIGHT=0
export LABEL_DRAWING="on"

# --- Item background ----------------------------------------------------------
export ITEM_BG_CORNER_RADIUS=3
export ITEM_BG_HEIGHT=20

# --- Workspaces ---------------------------------------------------------------
# #workspaces button { padding: 0 6px; margin: 0 1.5px }
export WS_ITEM_PADDING=2
export WS_LABEL_PADDING=6
# Omarchy declares persistent-workspaces 1-5, so those digits are always on the
# bar. AeroSpace has no such setting -- plugins/workspaces.sh unions this list
# with the workspaces that actually exist.
export WS_PERSISTENT="1 2 3 4 5"
# The glyph Omarchy uses for the focused workspace instead of its number.
export WS_ACTIVE_GLYPH="󱓻"

# --- Menus (popups) -----------------------------------------------------------
export MENU_WIDTH=290
export MENU_LABEL_WIDTH=232
export MENU_ROW_HEIGHT=26
export MENU_ROW_BG_IDLE=0x00000000
export MENU_BG_CORNER_RADIUS=6
export MENU_BG_BORDER_WIDTH=2
export MENU_Y_OFFSET=0
