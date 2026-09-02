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

total_bytes=$(sysctl -n hw.memsize)
total_gb=$(echo "$total_bytes" | awk '{printf "%.0f", $1/1073741824}')

free_gb=$(vm_stat | awk -v page_size=4096 '
  /page size of/       { page_size = $8 }
  /Pages free/         { free = $3 }
  /Pages inactive/     { inactive = $3 }
  /Pages speculative/  { spec = $4 }
  END {
    gsub(/\./, "", free)
    gsub(/\./, "", inactive)
    gsub(/\./, "", spec)
    available = (free + inactive + spec) * page_size
    printf "%.1f", available / 1073741824
  }
')

used_gb=$(echo "$total_gb $free_gb" | awk '{printf "%.1f", $1 - $2}')
used_pct=$(echo "$used_gb $total_gb" | awk '{printf "%.0f", ($1/$2)*100}')

sketchybar --set "$NAME" label="${used_gb}GB (${used_pct}%)"
