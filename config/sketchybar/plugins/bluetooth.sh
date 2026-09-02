#!/bin/bash

# Source Colors
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi

# Source Layout Variables
source "$CONFIG_DIR/variables.sh"

# Resolve blueutil rather than hardcoding a prefix: Homebrew lives in
# /opt/homebrew on Apple Silicon and /usr/local on Intel, and sketchybar's
# launchd environment does not always carry either on PATH.
BLUEUTIL=$(command -v blueutil 2>/dev/null)
[ -x "$BLUEUTIL" ] || for C in /opt/homebrew/bin/blueutil /usr/local/bin/blueutil; do
    [ -x "$C" ] && BLUEUTIL="$C" && break
done
SELF="$CONFIG_DIR/plugins/bluetooth.sh"

BT_POPUP_WIDTH=290
BT_LABEL_WIDTH=240
BT_ROW_HEIGHT=26
BT_ROW_BG_IDLE=0x00000000
BT_MAX_CONNECTED=8
BT_MAX_OTHER=24

CACHE="/tmp/sketchybar_bt_devices.$(id -u).cache"
CACHE_TTL=5

# sketchybar passes the item name in $NAME. Stash it: the device loop reads
# into its own variables and $NAME must survive that.
ITEM_NAME="${NAME:-bluetooth}"

# ── Device inventory ──────────────────────────────────────────────────────────
# system_profiler is the source of truth for names/types/connection state --
# it needs no Bluetooth privacy grant and reports the device class, which
# blueutil does not. blueutil is used only to act (power/connect/disconnect).
#
# Emits TSV: connected(1|0) \t type \t address \t name
# No field may be empty: bash treats tab as IFS whitespace, so a blank column
# would collapse and shift every field after it (hence type -> "unknown").
# Ordered the way the macOS picker does it: connected first, then audio, then
# input devices, then everything else; alphabetical within each group.
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

# system_profiler costs ~80ms, and both the bar item (every 15s) and the popup
# ask for the same data. Cache it briefly; invalidate_cache() drops it the
# moment we change something ourselves.
list_devices() {
  local AGE=99999
  if [ -s "$CACHE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
  fi

  if [ "$AGE" -lt "$CACHE_TTL" ]; then
    cat "$CACHE"
    return
  fi

  local OUT
  OUT=$(scan_devices)
  # Only replace a good cache with a non-empty scan.
  if [ -n "$OUT" ]; then
    printf '%s\n' "$OUT" > "$CACHE.tmp.$$" && mv -f "$CACHE.tmp.$$" "$CACHE"
    printf '%s\n' "$OUT"
  else
    [ -s "$CACHE" ] && cat "$CACHE"
  fi
}

invalidate_cache() { rm -f "$CACHE"; }

# Sets $ICON_OUT rather than echoing: $(...) would fork a subshell per device,
# and this runs once per row on every popup refresh.
ICON_OUT=""
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

# ── Popup refresh ─────────────────────────────────────────────────────────────
# Rows already exist (created once in items/bluetooth.sh). We only --set them,
# and hide the slots we do not need. Everything goes out in ONE sketchybar
# call: issuing them separately cost ~35 IPC round-trips (~240ms).

ARGS=()

fill_row() {
  ARGS+=( --set "$1"
              drawing=on
              "icon=$2"
              "icon.color=$4"
              "label=$3"
              "label.color=$4"
              "click_script=$5" )
}

refresh_popup() {
  ARGS=()

  local POWER
  POWER=$("$BLUEUTIL" --power 2>/dev/null)

  if [ "$POWER" != "1" ]; then
    ARGS+=( --set bluetooth.power icon="󰂲" label="Bluetooth: Off"
            "icon.color=$color3" "label.color=$color3" )
    ARGS+=( --set bluetooth.hdr.connected drawing=off )
    ARGS+=( --set bluetooth.hdr.other drawing=off )
    local i
    for i in $(seq 0 $((BT_MAX_CONNECTED - 1))); do ARGS+=( --set "bluetooth.device.c.$i" drawing=off ); done
    for i in $(seq 0 $((BT_MAX_OTHER - 1)));     do ARGS+=( --set "bluetooth.device.o.$i" drawing=off ); done
    sketchybar "${ARGS[@]}"
    return
  fi

  ARGS+=( --set bluetooth.power icon="󰂯" label="Bluetooth: On"
          "icon.color=$ACCENT_COLOR" "label.color=$ITEM_COLOR" )

  local CONN_I=0 OTHER_I=0 SLOT COLOR
  while IFS=$'\t' read -r DEV_CONN DEV_TYPE DEV_ADDR DEV_NAME; do
    [ -z "$DEV_ADDR" ] && continue
    icon_for "$DEV_TYPE"

    if [ "$DEV_CONN" = "1" ]; then
      [ "$CONN_I" -ge "$BT_MAX_CONNECTED" ] && continue
      SLOT="bluetooth.device.c.$CONN_I"; COLOR="$ACCENT_COLOR"
      CONN_I=$((CONN_I + 1))
    else
      [ "$OTHER_I" -ge "$BT_MAX_OTHER" ] && continue
      SLOT="bluetooth.device.o.$OTHER_I"; COLOR="$color7"
      OTHER_I=$((OTHER_I + 1))
    fi

    fill_row "$SLOT" "$ICON_OUT" "$DEV_NAME" "$COLOR" \
             "$SELF toggle_device '$DEV_ADDR'"
  done < <(list_devices)

  # Hide the slots we did not use, and any header with an empty section.
  local i
  for i in $(seq "$CONN_I"  $((BT_MAX_CONNECTED - 1))); do ARGS+=( --set "bluetooth.device.c.$i" drawing=off ); done
  for i in $(seq "$OTHER_I" $((BT_MAX_OTHER - 1)));     do ARGS+=( --set "bluetooth.device.o.$i" drawing=off ); done

  if [ "$CONN_I" -gt 0 ]; then ARGS+=( --set bluetooth.hdr.connected drawing=on )
  else                         ARGS+=( --set bluetooth.hdr.connected drawing=off ); fi
  if [ "$OTHER_I" -gt 0 ]; then ARGS+=( --set bluetooth.hdr.other drawing=on )
  else                          ARGS+=( --set bluetooth.hdr.other drawing=off ); fi
  ARGS+=( --set bluetooth.hdr.sep drawing=on )

  sketchybar "${ARGS[@]}"
}

# ── Bar item ──────────────────────────────────────────────────────────────────

update_bar_item() {
  local POWER
  POWER=$("$BLUEUTIL" --power 2>/dev/null)

  # Distinguish "radio is off" (0) from "blueutil could not answer" (empty).
  # Right after a wake the Bluetooth API is briefly unavailable; treating that
  # as "off" swapped the icon and hid the label, then reverted a tick later --
  # visible as flicker. Leave the item exactly as it is instead.
  [ -z "$POWER" ] && return

  if [ "$POWER" != "1" ]; then
    sketchybar --set "$ITEM_NAME" icon="󰂲" icon.color="$color3" label.drawing=off
    return
  fi

  local LINE DEV_TYPE DEV_NAME
  LINE=$(list_devices | awk -F'\t' '$1=="1"' | head -1)

  if [ -z "$LINE" ]; then
    sketchybar --set "$ITEM_NAME" icon="󰂯" icon.color="$ITEM_COLOR" label.drawing=off
    return
  fi

  DEV_TYPE=$(echo "$LINE" | cut -f2)
  DEV_NAME=$(echo "$LINE" | cut -f4)
  icon_for "$DEV_TYPE"

  local SHORT="${DEV_NAME:0:14}"
  [ "${#DEV_NAME}" -gt 14 ] && SHORT="${SHORT}…"

  sketchybar --set "$ITEM_NAME" \
    icon="$ICON_OUT" \
    icon.color="$ACCENT_COLOR" \
    label="$SHORT" label.drawing=on
}

# ── Click actions (dispatched via click_script arguments) ─────────────────────

case "$1" in
"populate")
  refresh_popup
  exit 0
  ;;
"row_hover")
  case "$SENDER" in
  "mouse.entered")
    sketchybar --set "$ITEM_NAME" background.color="$ITEM_BG_COLOR"
    ;;
  "mouse.exited" | "mouse.exited.global")
    sketchybar --set "$ITEM_NAME" background.color="$BT_ROW_BG_IDLE"
    ;;
  esac
  exit 0
  ;;
"toggle_power")
  if [ "$("$BLUEUTIL" --power)" = "1" ]; then
    "$BLUEUTIL" --power 0
  else
    "$BLUEUTIL" --power 1
  fi
  sleep 1
  invalidate_cache
  update_bar_item
  refresh_popup
  exit 0
  ;;
"toggle_device")
  ADDR="$2"
  WAS_CONNECTED=$("$BLUEUTIL" --is-connected "$ADDR")
  if [ "$WAS_CONNECTED" = "1" ]; then
    "$BLUEUTIL" --disconnect "$ADDR"
  else
    "$BLUEUTIL" --connect "$ADDR"
  fi

  # Poll until the radio actually reports the new state (a connect can take a
  # few seconds) so the redrawn popup shows the result rather than the old
  # state. Give up after ~6s and redraw whatever is true by then.
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    [ "$("$BLUEUTIL" --is-connected "$ADDR")" != "$WAS_CONNECTED" ] && break
    sleep 0.5
  done

  invalidate_cache
  update_bar_item
  # Refresh in place and leave the popup open, so the new state is visible
  # without having to reopen it.
  refresh_popup
  exit 0
  ;;
"open_settings")
  open "x-apple.systempreferences:com.apple.BluetoothSettings"
  sketchybar --set bluetooth popup.drawing=off
  exit 0
  ;;
esac

# ── Event dispatch ────────────────────────────────────────────────────────────

case "$SENDER" in
"display_change" | "space_change")
  # Popup rows are bound to the display they were built on; dismiss rather
  # than leave an empty frame behind on the monitor we just moved to.
  sketchybar --set bluetooth popup.drawing=off
  ;;
"mouse.clicked")
  if [ "$(sketchybar --query bluetooth | jq -r '.popup.drawing')" = "on" ]; then
    sketchybar --set "$ITEM_NAME" popup.drawing=off
  else
    # Show immediately -- the rows already hold the last known state -- then
    # refresh them in place. Building before showing is what made the popup
    # appear empty and fill in afterwards.
    sketchybar --set "$ITEM_NAME" popup.drawing=on
    refresh_popup
  fi
  ;;
*)
  update_bar_item
  ;;
esac
