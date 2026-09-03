#!/bin/bash
#
# Wi-Fi. Omarchy's network module launches a picker on click; this opens one
# directly in the bar.

NET_MAX_KNOWN=12

menu_item network right right
ARGS+=( --set network update_freq=15 label.drawing=off )

menu_row       network network.power
menu_header    network network.hdr.current "Verbunden"
menu_row       network network.current
menu_header    network network.hdr.known "Bekannte Netzwerke"
menu_rows      network network.known $NET_MAX_KNOWN
menu_separator network network.sep
menu_row       network network.settings

menu_flush

sketchybar --subscribe network wifi_change system_woke

"$PLUGIN_DIR/network.sh" populate &
