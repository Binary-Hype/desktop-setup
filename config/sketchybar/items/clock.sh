#!/bin/bash
#
# Clock. Omarchy puts it in the centre; here it sits at the far right, because
# the MacBook's notch owns the middle of the built-in display.
# Format follows Omarchy's "{:L%A %H:%M}" -- localised weekday plus time.

# Must match MENU_WIDTH: the popup is as wide as its widest row, and the
# separator below is a full-width menu row. A narrower value here left every
# centred line sitting 20pt off to the left.
CLOCK_POPUP_WIDTH=$MENU_WIDTH

menu_item clock right right
ARGS+=( --set clock update_freq=10 icon.drawing=off )

# Blank rows top and bottom. A popup row's height comes from its font, so an
# item with nothing drawn is the way to keep the clock off the popup border.
spacer() {
  ARGS+=( --add item "$1" popup.clock
          --set "$1"
              "width=$CLOCK_POPUP_WIDTH"
              icon.drawing=off
              label.drawing=off
              background.drawing=off )
}

spacer clock.pad_top

# Big clock, ticking once a second while the popup is open.
ARGS+=( --add item clock.time popup.clock
        --set clock.time
            update_freq=1
            "width=$CLOCK_POPUP_WIDTH"
            icon.drawing=off
            "label.width=$CLOCK_POPUP_WIDTH"
            label.align=center
            label.padding_left=0
            label.padding_right=0
            "label.color=$ITEM_COLOR"
            "label.font=JetBrains Mono:Bold:28.0"
            "script=sketchybar --set \$NAME label=\"\$(date '+%H:%M:%S')\"" )

ARGS+=( --add item clock.date popup.clock
        --set clock.date
            "width=$CLOCK_POPUP_WIDTH"
            icon.drawing=off
            "label.width=$CLOCK_POPUP_WIDTH"
            label.align=center
            label.padding_left=0
            label.padding_right=0
            "label.color=$TEXT_COLOR"
            "label.font=JetBrainsMono Nerd Font:Regular:12.0" )

menu_separator clock clock.sep
ARGS+=( --set clock.sep drawing=on )

# Month grid. A fixed pool -- `cal` prints at most 6 week rows plus the header;
# the rows are refilled on every open so the grid rolls over into a new month.
for i in $(seq 0 7); do
  ARGS+=( --add item "clock.cal.$i" popup.clock
          --set "clock.cal.$i"
              drawing=off
              "width=$CLOCK_POPUP_WIDTH"
              icon.drawing=off
              "label.width=$CLOCK_POPUP_WIDTH"
              label.align=center
              label.padding_left=0
              label.padding_right=0
              "label.color=$ITEM_COLOR"
              "label.font=Menlo:Regular:12.0" )
done

spacer clock.pad_bottom

menu_flush

# Fill the calendar now so the first open is never empty.
"$PLUGIN_DIR/clock.sh" populate &
