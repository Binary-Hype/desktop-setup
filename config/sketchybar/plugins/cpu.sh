#!/bin/bash

# Source Colors
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi

# Source Layout Variables
source "$CONFIG_DIR/variables.sh"

case "$SENDER" in
"mouse.clicked")
  # Native macOS system monitor. (The upstream config launched btop inside
  # kitty and sized it with xdpyinfo, an X11 tool that does not exist here.)
  open -a "Activity Monitor"
  exit 0
  ;;
esac

CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v "$(whoami)" | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep "$(whoami)" | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")

CPU_PERCENT="$(echo "$CPU_SYS $CPU_USER" | awk '{printf "%.0f\n", ($1 + $2)*100}')"

sketchybar --set "$NAME" label="$CPU_PERCENT%"
