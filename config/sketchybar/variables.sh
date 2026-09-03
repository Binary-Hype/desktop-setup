#!/bin/bash
#
# Geometry, fonts and menu metrics. Values mirror Omarchy's Waybar
# (basecamp/omarchy: config/waybar/config.jsonc + style.css) so the bar reads
# the same on macOS; the Waybar rule each one comes from is noted inline.
#
# Colours live in colors.sh -- deliberately separate, because
# ~/.config/borders/bordersrc sources that file too.

# --- Bar Appearance -----------------------------------------------------------
# Omarchy's bar is flat and full width: no margin, no radius, `border: none`.
# Nothing floats, so there is no y_offset and no blur.
#
# Height deviates from Omarchy's 26: the built-in display's usable area starts
# 32pt down (notch / safe-area inset), and AeroSpace cannot place a window
# above that. A 26pt bar therefore leaves a 6pt gap below it that no gap
# setting can close. 29pt brings that down to 3pt -- the same gap the window
# borders get everywhere else.
export BAR_HEIGHT=29
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
# Text is Cascadia Code; icons are Phosphor (https://phosphoricons.com).
# Omarchy uses JetBrainsMono Nerd Font at 12px; 13pt matches that optically at
# macOS' point scale. Icons run larger, as Phosphor's outlines read lighter
# than a text glyph of the same size.
export BAR_FONT="Cascadia Code NF"
export ICON_FAMILY="Phosphor"
export ICON_FONT="$ICON_FAMILY:Regular:16.0"
export LABEL_FONT="$BAR_FONT:Regular:13.0"
export ICON_PADDING_LEFT=0
export ICON_PADDING_RIGHT=0
export ICON_DRAWING="on"
export LABEL_PADDING_LEFT=0
export LABEL_PADDING_RIGHT=0
export LABEL_DRAWING="on"

# --- Item background ----------------------------------------------------------
export ITEM_BG_CORNER_RADIUS=3
export ITEM_BG_HEIGHT=22

# --- Workspaces ---------------------------------------------------------------
# #workspaces button { padding: 0 6px; margin: 0 1.5px }
export WS_ITEM_PADDING=2
export WS_LABEL_PADDING=6
# Omarchy declares persistent-workspaces 1-5, so those digits are always on the
# bar. AeroSpace has no such setting -- plugins/workspaces.sh unions this list
# with the workspaces that actually exist.
export WS_PERSISTENT="1 2 3 4 5"
# Omarchy replaces the focused workspace's number with a dot. Phosphor's
# outline circle is too faint at this size, so the dot is drawn from the Fill
# family (see ICON_WS_ACTIVE in lib/icons.sh).
export WS_ACTIVE_FONT="Phosphor-Fill:Regular:9.0"

# --- Menus (popups) -----------------------------------------------------------
export MENU_WIDTH=290
export MENU_LABEL_WIDTH=232
export MENU_ROW_HEIGHT=26
export MENU_ROW_BG_IDLE=0x00000000
# Keeps a row's background off the popup's own border. Flush against it, the
# rounded corners of each row poked through the border as little wedges down
# the popup's left edge.
export MENU_ROW_INSET=3
export MENU_BG_CORNER_RADIUS=6
export MENU_BG_BORDER_WIDTH=2
export MENU_Y_OFFSET=0
