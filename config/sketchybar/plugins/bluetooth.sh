#!/bin/bash

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/bluetooth.sh"
BLUEUTIL=$(bin_path blueutil)

BT_MAX_CONNECTED=8
BT_MAX_OTHER=20

CACHE="/tmp/sketchybar_bt.$(id -u).cache"
CACHE_TTL=5

# ── Device inventory ──────────────────────────────────────────────────────────
# system_profiler is the source of truth for names, types and connection state:
# it needs no Bluetooth privacy grant and reports the device class, which
# blueutil does not. blueutil is used only to act (power, connect, disconnect).
#
# Emits TSV: connected(1|0) \t type \t address \t name
# No field may be empty: bash treats tab as IFS whitespace, so a blank column
# would collapse and shift every field after it (hence type -> "unknown").
# Ordered the way the macOS picker does it: connected first, then audio, then
# input devices, then the rest; alphabetical within each group.
scan_devices() {
  system_profiler SPBluetoothDataType -json 2>/dev/null | jq -r '
    def trank:
      ((.type // "") | ascii_downcase) as $t
      | if   ($t | test("headphone|headset|speaker|audio|airpod")) then 0
        elif ($t | test("keyboard|mouse|trackpad"))                then 1
        else 2 end;

    (.SPBluetoothDataType[0] // {}) as $d
    | ( (($d.device_connected     // []) | map(to_entries[] | {n:.key, v:.value, c:true}))
      + (($d.device_not_connected // []) | map(to_entries[] | {n:.key, v:.value, c:false})) )
    | map({ name: .n, connected: .c,
            addr: (.v.device_address // ""),
            type: (.v.device_minorType // "" | if . == "" then "unknown" else . end) })
    | map(select(.addr != ""))
    | sort_by( (if .connected then 0 else 1 end), trank, (.name | ascii_downcase) )
    | .[]
    | [ (if .connected then "1" else "0" end), .type,
        (.addr | ascii_downcase | gsub(":"; "-")), .name ]
    | @tsv'
}

list_devices() {
  cache_get "$CACHE" "$CACHE_TTL" && return
  scan_devices | cache_put "$CACHE" || cat "$CACHE" 2>/dev/null
}

# Sets ICON_OUT rather than echoing: $(...) would fork a subshell per device,
# and this runs once per row on every refresh.
icon_for() {
  shopt -s nocasematch
  case "$1" in
    *headphone*|*headset*|*airpod*) ICON_OUT="󰋋" ;;
    *speaker*|*audio*)              ICON_OUT="󰓃" ;;
    *keyboard*)                     ICON_OUT="󰌌" ;;
    *trackpad*)                     ICON_OUT="󰟸" ;;
    *mouse*)                        ICON_OUT="󰍽" ;;
    *phone*)                        ICON_OUT="󰄜" ;;
    *watch*)                        ICON_OUT="󰖉" ;;
    *tablet*|*ipad*)                ICON_OUT="󰓶" ;;
    *)                              ICON_OUT="󰂯" ;;
  esac
  shopt -u nocasematch
}

populate() {
  ARGS=()
  local power
  power=$("$BLUEUTIL" --power 2>/dev/null)

  if [ "$power" != "1" ]; then
    menu_set bluetooth.power "󰂲" "Bluetooth: Aus" "$color3" "$SELF toggle_power"
    ARGS+=( --set bluetooth.hdr.connected drawing=off
            --set bluetooth.hdr.other     drawing=off )
    menu_hide_range bluetooth.dev.c 0 $((BT_MAX_CONNECTED - 1))
    menu_hide_range bluetooth.dev.o 0 $((BT_MAX_OTHER - 1))
    menu_set bluetooth.settings "󰒓" "Bluetooth-Einstellungen…" "$color7" "$SELF settings"
    ARGS+=( --set bluetooth.sep drawing=on )
    menu_flush
    return
  fi

  menu_set bluetooth.power "󰂯" "Bluetooth: An" "$ACCENT_COLOR" "$SELF toggle_power"

  local conn=0 other=0 slot color
  while IFS=$'\t' read -r dev_conn dev_type dev_addr dev_name; do
    [ -z "$dev_addr" ] && continue
    icon_for "$dev_type"

    if [ "$dev_conn" = "1" ]; then
      [ "$conn" -ge "$BT_MAX_CONNECTED" ] && continue
      slot="bluetooth.dev.c.$conn"; color="$ACCENT_COLOR"
      conn=$((conn + 1))
    else
      [ "$other" -ge "$BT_MAX_OTHER" ] && continue
      slot="bluetooth.dev.o.$other"; color="$color7"
      other=$((other + 1))
    fi

    menu_set "$slot" "$ICON_OUT" "$dev_name" "$color" "$SELF toggle_device '$dev_addr'"
  done < <(list_devices)

  menu_hide_range bluetooth.dev.c "$conn"  $((BT_MAX_CONNECTED - 1))
  menu_hide_range bluetooth.dev.o "$other" $((BT_MAX_OTHER - 1))

  if [ "$conn" -gt 0 ];  then ARGS+=( --set bluetooth.hdr.connected drawing=on )
  else                        ARGS+=( --set bluetooth.hdr.connected drawing=off ); fi
  if [ "$other" -gt 0 ]; then ARGS+=( --set bluetooth.hdr.other drawing=on )
  else                        ARGS+=( --set bluetooth.hdr.other drawing=off ); fi

  menu_set bluetooth.settings "󰒓" "Bluetooth-Einstellungen…" "$color7" "$SELF settings"
  ARGS+=( --set bluetooth.sep drawing=on )
  menu_flush
}

update_bar_item() {
  local item="${NAME:-bluetooth}" power
  power=$("$BLUEUTIL" --power 2>/dev/null)

  # Distinguish "radio is off" (0) from "blueutil could not answer" (empty).
  # Right after a wake the Bluetooth API is briefly unavailable; treating that
  # as "off" swapped the icon and reverted a tick later -- visible as flicker.
  # Leave the item exactly as it is instead.
  [ -z "$power" ] && return

  if [ "$power" != "1" ]; then
    sketchybar --set "$item" icon="󰂲" icon.color="$color3" label.drawing=off
    return
  fi

  # Omarchy: format-connected "󰂱", format "" (plain) -- icon only, no name.
  if [ -n "$(list_devices | awk -F'\t' '$1=="1"' | head -1)" ]; then
    sketchybar --set "$item" icon="󰂱" icon.color="$ACCENT_COLOR" label.drawing=off
  else
    sketchybar --set "$item" icon="󰂯" icon.color="$ITEM_COLOR" label.drawing=off
  fi
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
"toggle_power")
  if [ "$("$BLUEUTIL" --power)" = "1" ]; then "$BLUEUTIL" --power 0; else "$BLUEUTIL" --power 1; fi
  sleep 1
  cache_drop "$CACHE"
  update_bar_item
  populate
  exit 0
  ;;
"toggle_device")
  ADDR="$2"
  WAS_CONNECTED=$("$BLUEUTIL" --is-connected "$ADDR")
  if [ "$WAS_CONNECTED" = "1" ]; then "$BLUEUTIL" --disconnect "$ADDR"; else "$BLUEUTIL" --connect "$ADDR"; fi

  # Poll until the radio reports the new state (a connect can take a few
  # seconds) so the redrawn menu shows the result rather than the old state.
  # Give up after ~6s and draw whatever is true by then.
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    [ "$("$BLUEUTIL" --is-connected "$ADDR")" != "$WAS_CONNECTED" ] && break
    sleep 0.5
  done

  cache_drop "$CACHE"
  update_bar_item
  # Refresh in place and leave the menu open, so the new state is visible
  # without having to reopen it.
  populate
  exit 0
  ;;
"settings")
  menu_close bluetooth
  open "x-apple.systempreferences:com.apple.BluetoothSettings"
  exit 0
  ;;
esac

case "$SENDER" in
"display_change" | "space_change")
  menu_close bluetooth
  ;;
"mouse.clicked")
  if menu_is_open bluetooth; then
    menu_close bluetooth
  else
    menu_open bluetooth
    populate
  fi
  ;;
*)
  update_bar_item
  ;;
esac
