#!/bin/bash

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

# sketchybar runs under launchd, which carries no locale -- without this, the
# weekday would come out English regardless of the system language.
export LC_TIME=de_DE.UTF-8

CAL_ROWS=8

# Rebuild the month grid from scratch. Doing this on every open (rather than
# once at bar start, as the old config did) is what makes it roll over into the
# next month.
populate() {
  ARGS=()
  ARGS+=( --set clock.date label="$(date '+%d.%m.%Y')" )

  # Rows are left-aligned at a fixed indent (see CAL_INDENT in items/clock.sh),
  # so nothing here has to pad them. `cal` ends with a blank line -- dropped,
  # the bottom spacing comes from clock.pad_bottom.
  local i=0 line
  while IFS= read -r line; do
    [ "$i" -ge "$CAL_ROWS" ] && break
    ARGS+=( --set "clock.cal.$i" drawing=on "label=$line" )
    i=$((i + 1))
  done < <(cal | grep -v '^[[:space:]]*$')

  menu_hide_range clock.cal "$i" $((CAL_ROWS - 1))
  menu_flush
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
esac

case "$SENDER" in
"mouse.exited.global" | "display_change")
  menu_close clock
  ;;
"mouse.clicked")
  if menu_is_open clock; then
    menu_close clock
  else
    menu_open clock
    populate
  fi
  ;;
*)
  sketchybar --set clock label="$(date '+%A %H:%M')"
  ;;
esac
