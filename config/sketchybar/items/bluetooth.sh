#!/bin/bash

# Popup geometry. Row height is fixed and the row background is ALWAYS drawn
# (transparent when idle) so hovering only swaps a colour and can never
# resize a row.
BT_POPUP_WIDTH=290
BT_LABEL_WIDTH=240
BT_ROW_HEIGHT=26
BT_ROW_BG_IDLE=0x00000000

# The popup uses a FIXED pool of rows, created once here and only ever
# updated afterwards. Removing and re-adding rows on each open made the
# popup frame appear before its contents had been laid out.
BT_MAX_CONNECTED=8
BT_MAX_OTHER=24

sketchybar --add item bluetooth right \
           --set bluetooth \
                 update_freq=15 \
                 script="$PLUGIN_DIR/bluetooth.sh" \
                 popup.align=right \
                 popup.height=2 \
                 popup.background.border_width=2 \
                 popup.background.corner_radius=3 \
                 popup.background.color="$background" \
                 popup.horizontal=off \
           --subscribe bluetooth mouse.clicked \
           --subscribe bluetooth display_change \
           --subscribe bluetooth space_change

ARGS=()

# A selectable row: hover highlight + click action, hidden until the plugin
# fills it in.
queue_row() {
  ARGS+=( --add item "$1" popup.bluetooth
          --set "$1"
              display=active
              drawing=off
              "width=$BT_POPUP_WIDTH"
              icon.padding_left=12
              icon.padding_right=8
              "label.width=$BT_LABEL_WIDTH"
              label.align=left
              background.drawing=on
              "background.color=$BT_ROW_BG_IDLE"
              background.corner_radius=4
              "background.height=$BT_ROW_HEIGHT"
              "script=$PLUGIN_DIR/bluetooth.sh row_hover"
          --subscribe "$1" mouse.entered mouse.exited mouse.exited.global )
}

# A non-interactive section label.
queue_header() {
  ARGS+=( --add item "$1" popup.bluetooth
          --set "$1"
              display=active
              drawing=off
              icon.drawing=off
              "width=$BT_POPUP_WIDTH"
              "label=$2"
              "label.width=$BT_LABEL_WIDTH"
              label.align=left
              label.padding_left=12
              "label.color=$color3"
              "label.font=$LABEL_FONT:Bold:11.0"
              background.drawing=on
              "background.color=$BT_ROW_BG_IDLE"
              "background.height=$BT_ROW_HEIGHT" )
}

# Order here is the order the popup renders in.
queue_row    bluetooth.power
ARGS+=( --set bluetooth.power drawing=on
        "click_script=$PLUGIN_DIR/bluetooth.sh toggle_power" )

queue_header bluetooth.hdr.connected "Connected"
for i in $(seq 0 $((BT_MAX_CONNECTED - 1))); do queue_row "bluetooth.device.c.$i"; done

queue_header bluetooth.hdr.other "Other Devices"
for i in $(seq 0 $((BT_MAX_OTHER - 1))); do queue_row "bluetooth.device.o.$i"; done

queue_header bluetooth.hdr.sep ""
queue_row    bluetooth.device.settings
ARGS+=( --set bluetooth.device.settings
        drawing=on
        icon="󰒓"
        "icon.color=$color7"
        label="Bluetooth Settings…"
        "label.color=$color7"
        "click_script=$PLUGIN_DIR/bluetooth.sh open_settings" )

sketchybar "${ARGS[@]}"

# Fill the popup now so the first open is never empty. Backgrounded so it
# does not hold up the rest of the bar's startup.
"$PLUGIN_DIR/bluetooth.sh" populate &
