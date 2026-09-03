#!/bin/bash

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/system.sh"
SYS_TOP_PROCS=5

# Total CPU load in percent, normalised over all threads. Split into system and
# user because `ps` reports per-process figures that add up past 100% on a
# multi-core machine.
cpu_percent() {
  local cores info sys user
  cores=$(sysctl -n machdep.cpu.thread_count)
  info=$(ps -eo pcpu,user)
  sys=$(echo "$info"  | grep -v "$(whoami)" | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $cores)}")
  user=$(echo "$info" | grep "$(whoami)"    | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $cores)}")
  echo "$sys $user" | awk '{printf "%.0f", ($1 + $2) * 100}'
}

# Used memory in GB and percent. "Available" is free + inactive + speculative,
# which is what Activity Monitor treats as reclaimable.
memory_usage() {
  local total free
  total=$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1073741824}')
  free=$(vm_stat | awk -v page_size=4096 '
    /page size of/      { page_size = $8 }
    /Pages free/        { free = $3 }
    /Pages inactive/    { inactive = $3 }
    /Pages speculative/ { spec = $4 }
    END {
      gsub(/\./, "", free); gsub(/\./, "", inactive); gsub(/\./, "", spec)
      printf "%.1f", ((free + inactive + spec) * page_size) / 1073741824
    }')
  echo "$total $free" | awk '{printf "%.1f GB (%.0f %%)", $1 - $2, (($1 - $2) / $1) * 100}'
}

uptime_short() {
  # Match "{ sec = N," specifically -- a greedy .*sec would land on "usec".
  sysctl -n kern.boottime \
    | sed -E 's/^\{ sec = ([0-9]+).*/\1/' \
    | awk -v now="$(date +%s)" '{
        s = now - $1; d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60)
        if (d > 0) printf "%dd %dh", d, h; else if (h > 0) printf "%dh %dm", h, m; else printf "%dm", m
      }'
}

update_bar_item() {
  # Icon-only on the bar, exactly like Omarchy's cpu module. The figure is one
  # click away.
  sketchybar --set "${NAME:-system}" icon="$ICON_CPU" label.drawing=off
}

populate() {
  ARGS=()
  menu_info system.cpu    "$ICON_CPU"    "CPU      $(cpu_percent) %"    "$ACCENT_COLOR"
  menu_info system.ram    "$ICON_RAM"    "RAM      $(memory_usage)"     "$ITEM_COLOR"
  menu_info system.uptime "$ICON_UPTIME" "Uptime   $(uptime_short)"     "$ITEM_COLOR"

  # Process rows are informational only -- nothing gets killed from the bar.
  local i=0 pcpu comm
  while read -r pcpu comm; do
    [ "$i" -ge "$SYS_TOP_PROCS" ] && break
    [ -z "$comm" ] && continue
    menu_info "system.proc.$i" "" "$(printf '%-22.22s %5s %%' "$comm" "$pcpu")" "$color7"
    i=$((i + 1))
  done < <(ps -Aceo pcpu,comm -r | tail -n +2 | head -n "$SYS_TOP_PROCS")
  menu_hide_range system.proc "$i" $((SYS_TOP_PROCS - 1))

  menu_set system.monitor "$ICON_SETTINGS" "Activity Monitor…" "$color7" "$SELF monitor"

  ARGS+=( --set system.hdr.system drawing=on
          --set system.hdr.procs  drawing=on
          --set system.sep        drawing=on )
  menu_flush
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
"monitor")
  menu_close system
  open -a "Activity Monitor"
  exit 0
  ;;
esac

case "$SENDER" in
"mouse.exited.global" | "display_change")
  menu_close system
  ;;
"mouse.clicked")
  if menu_is_open system; then
    menu_close system
  else
    menu_open system
    populate
  fi
  ;;
*)
  update_bar_item
  # Keep the menu current while it is open, so the figures are live rather than
  # frozen at the moment it was opened.
  menu_is_open system && populate
  ;;
esac
