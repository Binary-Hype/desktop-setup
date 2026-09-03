#!/bin/bash
#
# Battery. Omarchy puts its power menu behind this icon (on-click:
# "omarchy-menu power"), so the status lines and the power actions share one
# popup here too.

menu_item battery right right
ARGS+=( --set battery update_freq=120 label.drawing=off )

menu_row       battery battery.charge
menu_row       battery battery.source
menu_row       battery battery.lpm
menu_separator battery battery.sep1
menu_row       battery battery.lock
menu_row       battery battery.sleep
menu_row       battery battery.restart
menu_row       battery battery.shutdown
menu_separator battery battery.sep2
menu_row       battery battery.settings

menu_flush

# --subscribe needs the item to exist, so it comes after the flush.
sketchybar --subscribe battery system_woke power_source_change

"$PLUGIN_DIR/battery.sh" populate &
