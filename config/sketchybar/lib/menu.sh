#!/bin/bash
#
# menu.sh -- the popup menu framework.
#
# Every bar icon that reacts to a click opens one of these instead of launching
# an app or a System Settings pane. They are built the way the macOS menu bar
# menus behave: a status line, clickable entries with a hover highlight, and a
# single "…" escape hatch at the very bottom.
#
# Two rules run through everything here, both learned the hard way:
#
#   1. Rows are created ONCE, at bar start, as a fixed pool. Refreshing only
#      --sets them. Adding and removing rows per open makes the popup frame
#      appear before its contents are laid out.
#   2. Every change is accumulated in $ARGS and sent as ONE sketchybar call.
#      Issued separately, a device list cost ~35 IPC round-trips (~240ms).
#
# Item files use menu_item/menu_row/menu_header/menu_separator to declare the
# pool, then menu_flush. Plugins use menu_set/menu_info/menu_hide + menu_flush
# to fill it.

ARGS=()

menu_flush() {
  [ ${#ARGS[@]} -eq 0 ] && return 0
  sketchybar "${ARGS[@]}"
  ARGS=()
}

# menu_item NAME POSITION [ALIGN]
# Bar item that owns a popup. ALIGN defaults to the item's own side.
menu_item() {
  local name="$1" position="$2" align="${3:-$2}"
  ARGS+=( --add item "$name" "$position"
          --set "$name"
              "script=$PLUGIN_DIR/$name.sh"
              popup.horizontal=off
              "popup.align=$align"
              popup.height=2
              "popup.y_offset=$MENU_Y_OFFSET"
              "popup.background.color=$BAR_COLOR"
              "popup.background.corner_radius=$MENU_BG_CORNER_RADIUS"
              "popup.background.border_width=$MENU_BG_BORDER_WIDTH"
              "popup.background.border_color=$ACCENT_COLOR"
          # mouse.exited.global fires once the pointer has left the bar AND
          # every popup row, which is the closest thing sketchybar offers to
          # "clicked somewhere else" -- you have to move the pointer there
          # anyway. front_app_switched is deliberately NOT used: it also fires
          # for a screenshot hotkey, which made an open menu impossible to
          # capture. display_change/space_change: popup rows are bound to the
          # display they were built on, so dismiss rather than strand an empty
          # frame on the monitor we just moved to. space_change is NOT used:
          # AeroSpace does not use macOS Spaces, and macOS fires it for the
          # screenshot overlay -- which closed every menu before it could be
          # captured.
          --subscribe "$name" mouse.clicked mouse.exited.global display_change )
}

# menu_row PARENT NAME -- a clickable entry. Hidden until a plugin fills it.
# The row background is ALWAYS drawn (transparent when idle) so hovering only
# swaps a colour and can never resize the row.
menu_row() {
  local parent="$1" name="$2"
  ARGS+=( --add item "$name" "popup.$parent"
          --set "$name"
              display=active
              drawing=off
              "width=$MENU_WIDTH"
              icon.padding_left=12
              icon.padding_right=8
              "label.width=$MENU_LABEL_WIDTH"
              label.align=left
              background.drawing=on
              "background.color=$MENU_ROW_BG_IDLE"
              background.corner_radius=4
              "background.padding_left=$MENU_ROW_INSET"
              "background.padding_right=$MENU_ROW_INSET"
              "background.height=$MENU_ROW_HEIGHT"
              "script=$LIB_DIR/hover.sh"
          --subscribe "$name" mouse.entered mouse.exited mouse.exited.global )
}

# menu_rows PARENT PREFIX COUNT -- a pool PREFIX.0 … PREFIX.(COUNT-1).
menu_rows() {
  local parent="$1" prefix="$2" count="$3" i
  for i in $(seq 0 $((count - 1))); do menu_row "$parent" "$prefix.$i"; done
}

# menu_header PARENT NAME TEXT -- non-interactive section label.
menu_header() {
  local parent="$1" name="$2" text="$3"
  ARGS+=( --add item "$name" "popup.$parent"
          --set "$name"
              display=active
              drawing=off
              icon.drawing=off
              "width=$MENU_WIDTH"
              "label=$text"
              "label.width=$MENU_LABEL_WIDTH"
              label.align=left
              label.padding_left=12
              "label.color=$color3"
              "label.font=$BAR_FONT:Bold:10.0"
              background.drawing=on
              "background.color=$MENU_ROW_BG_IDLE"
              "background.padding_left=$MENU_ROW_INSET"
              "background.padding_right=$MENU_ROW_INSET"
              background.height=20 )
}

# menu_separator PARENT NAME -- hairline between sections.
menu_separator() {
  local parent="$1" name="$2"
  ARGS+=( --add item "$name" "popup.$parent"
          --set "$name"
              display=active
              drawing=off
              icon.drawing=off
              label.drawing=off
              "width=$MENU_WIDTH"
              background.drawing=on
              "background.color=$color2"
              background.height=1
              background.corner_radius=0
              background.padding_left=12
              background.padding_right=12 )
}

# menu_set NAME ICON LABEL COLOR [CLICK] -- fill a clickable row.
menu_set() {
  ARGS+=( --set "$1"
              drawing=on
              "icon=$2"
              "icon.color=$4"
              "label=$3"
              "label.color=$4"
              "click_script=${5-}" )
}

# menu_info NAME ICON LABEL COLOR -- a row that shows a value but does nothing
# when clicked (status lines, process lists).
menu_info() {
  ARGS+=( --set "$1"
              drawing=on
              "icon=$2"
              "icon.color=$4"
              "label=$3"
              "label.color=$4"
              click_script=""
              "background.color=$MENU_ROW_BG_IDLE" )
}

# menu_show NAME... / menu_hide NAME...
menu_show() { local n; for n in "$@"; do ARGS+=( --set "$n" drawing=on ); done; }
menu_hide() { local n; for n in "$@"; do ARGS+=( --set "$n" drawing=off ); done; }

# menu_hide_range PREFIX FROM TO -- hide the unused tail of a row pool.
menu_hide_range() {
  local prefix="$1" from="$2" to="$3" i
  [ "$from" -gt "$to" ] && return 0
  for i in $(seq "$from" "$to"); do ARGS+=( --set "$prefix.$i" drawing=off ); done
}

menu_is_open() {
  [ "$(sketchybar --query "$1" 2>/dev/null | jq -r '.popup.drawing')" = "on" ]
}

menu_close() { sketchybar --set "$1" popup.drawing=off; }

# menu_open NAME -- show the popup immediately with whatever the rows already
# hold, so it never appears empty and fills in visibly afterwards. The caller
# refreshes in place right after.
menu_open() { sketchybar --set "$1" popup.drawing=on; }
