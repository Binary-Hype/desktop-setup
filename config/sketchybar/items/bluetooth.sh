#!/bin/bash
#
# Bluetooth device picker -- the menu the others are modelled on.

BT_MAX_CONNECTED=8
BT_MAX_OTHER=20

menu_item bluetooth right right
ARGS+=( --set bluetooth update_freq=15 label.drawing=off )

menu_row       bluetooth bluetooth.power
menu_header    bluetooth bluetooth.hdr.connected "Verbunden"
menu_rows      bluetooth bluetooth.dev.c $BT_MAX_CONNECTED
menu_header    bluetooth bluetooth.hdr.other "Weitere Geräte"
menu_rows      bluetooth bluetooth.dev.o $BT_MAX_OTHER
menu_separator bluetooth bluetooth.sep
menu_row       bluetooth bluetooth.settings

menu_flush

# Fill the menu now so the first open is never empty. Backgrounded so it does
# not hold up the rest of the bar's startup.
"$PLUGIN_DIR/bluetooth.sh" populate &
