#!/bin/bash
#
# Clock. Omarchy puts it in the centre; here it sits at the far right, because
# the MacBook's notch owns the middle of the built-in display.
# Format follows Omarchy's "{:L%A %H:%M}" -- localised weekday plus time.

# The month grid is what sets the popup's size. `cal` prints 22 columns, but
# the last two are always blank, so 20 columns is the visible block:
#   Cascadia advance = 0.5859 em -> 12pt * 0.5859 = 7.03pt per column
#   20 columns = 140.6pt, plus a 16pt margin either side -> 173pt
# Every row in this popup has to use that width, the separator included: the
# popup is as wide as its widest row.
CAL_FONT_SIZE=12.0
CAL_INDENT=16
CLOCK_POPUP_WIDTH=173

menu_item clock right right
ARGS+=( --set clock update_freq=10 icon.drawing=off )

# Shared by every row below. Item padding is zeroed so the margins come from
# CAL_INDENT alone, rather than from that plus the bar's default item padding.
row() {
  ARGS+=( --add item "$1" popup.clock
          --set "$1"
              "width=$CLOCK_POPUP_WIDTH"
              icon.drawing=off
              padding_left=0
              padding_right=0
              "label.width=$CLOCK_POPUP_WIDTH"
              label.padding_left=0
              label.padding_right=0
              "background.padding_left=$MENU_ROW_INSET"
              "background.padding_right=$MENU_ROW_INSET" )
}

# Blank rows top and bottom, so the clock and the grid do not sit against the
# popup border. The height has to come from a drawn (but fully transparent)
# background: a label alone does not set it, and an empty or all-space label
# measures as nothing anyway -- CoreText ignores trailing whitespace.
NBSP=$(printf '\302\240')

spacer() {
  row "$1"
  ARGS+=( --set "$1"
              "label=$NBSP"
              "label.font=$BAR_FONT:Regular:6.0"
              background.drawing=on
              background.color=0x00000000
              "background.padding_left=$MENU_ROW_INSET"
              "background.padding_right=$MENU_ROW_INSET"
              "background.height=$2" )
}

spacer clock.pad_top 14

# Big clock, ticking once a second while the popup is open.
row clock.time
ARGS+=( --set clock.time
            update_freq=1
            label.align=center
            "label.color=$ITEM_COLOR"
            "label.font=$BAR_FONT:Bold:28.0"
            "script=sketchybar --set \$NAME label=\"\$(date '+%H:%M:%S')\"" )

row clock.date
ARGS+=( --set clock.date
            label.align=center
            "label.color=$TEXT_COLOR"
            "label.font=$BAR_FONT:Regular:12.0" )

menu_separator clock clock.sep
# Item padding zeroed like every other row here, or the separator alone makes
# the popup wider than the grid and the right margin inflates.
ARGS+=( --set clock.sep drawing=on "width=$CLOCK_POPUP_WIDTH"
        padding_left=0 padding_right=0 )

# Month grid. Left-aligned at a fixed indent rather than centred: CoreText
# ignores trailing whitespace when measuring, so a centred short week ("27 28
# 29 30") drifted out from under the columns above it. Leading whitespace IS
# measured, so left alignment keeps cal's own indentation intact.
#
# A fixed pool -- `cal` prints at most 6 week rows plus the header; the rows are
# refilled on every open so the grid rolls over into a new month.
for i in $(seq 0 7); do
  row "clock.cal.$i"
  ARGS+=( --set "clock.cal.$i"
              drawing=off
              label.align=left
              "label.padding_left=$CAL_INDENT"
              "label.color=$ITEM_COLOR"
              "label.font=$BAR_FONT:Regular:$CAL_FONT_SIZE" )
done

spacer clock.pad_bottom 10

menu_flush

# Fill the calendar now so the first open is never empty.
"$PLUGIN_DIR/clock.sh" populate &
