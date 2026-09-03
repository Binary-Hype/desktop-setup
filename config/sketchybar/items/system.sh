#!/bin/bash
#
# Omarchy's cpu module (icon 󰍛, on-click opens btop). Here the click opens a
# menu instead, which also carries the RAM figures -- Omarchy has no memory
# module, so the numbers live one level down rather than on the bar.

SYS_TOP_PROCS=5

menu_item system right right
ARGS+=( --set system update_freq=5 icon="󰍛" label.drawing=off )

menu_header system system.hdr.system "System"
menu_row    system system.cpu
menu_row    system system.ram
menu_row    system system.uptime
menu_header system system.hdr.procs "Top-Prozesse"
menu_rows   system system.proc $SYS_TOP_PROCS
menu_separator system system.sep
menu_row    system system.monitor

menu_flush

"$PLUGIN_DIR/system.sh" populate &
