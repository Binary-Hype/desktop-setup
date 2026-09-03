#!/bin/bash
#
# Volume. Omarchy's pulseaudio module opens an audio app on click; this opens a
# menu with a scrollable level row and the output devices, the way the macOS
# sound menu works.

VOL_MAX_DEVICES=8

menu_item volume right right
ARGS+=( --set volume label.drawing=off )

menu_row volume volume.level
# The level row handles its own scroll events, so it needs its own script
# rather than the shared hover handler.
ARGS+=( --set volume.level "script=$PLUGIN_DIR/volume.sh row" )

menu_row       volume volume.mute
menu_header    volume volume.hdr.output "Ausgabe"
menu_rows      volume volume.dev $VOL_MAX_DEVICES
menu_separator volume volume.sep
menu_row       volume volume.settings

menu_flush

# --subscribe needs the items to exist, so it comes after the flush.
sketchybar --subscribe volume volume_change mouse.scrolled \
           --subscribe volume.level mouse.scrolled

"$PLUGIN_DIR/volume.sh" populate &
