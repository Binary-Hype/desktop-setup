#!/bin/bash
#
# Wi-Fi menu.
#
# A note on network names: since macOS 15 the SSID is redacted for any process
# without Location Services authorisation -- `networksetup -getairportnetwork`
# lies outright ("not associated" while connected), and system_profiler and
# `ipconfig getsummary` both return "<redacted>". sketchybar cannot obtain that
# authorisation. So the connected row reports signal and band rather than a
# name, and the switchable list comes from the preferred-networks list, which
# is NOT redacted.

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/network.sh"
NET_MAX_KNOWN=12

CACHE="/tmp/sketchybar_wifi.$(id -u).cache"
CACHE_TTL=20

WIFI_IF=$(networksetup -listallhardwareports 2>/dev/null \
            | awk '/Hardware Port: Wi-Fi/{getline; print $2}')

# ── State ─────────────────────────────────────────────────────────────────────
# One system_profiler call answers "connected?", signal and channel. It costs
# ~1s, and both the bar item (every 15s) and the popup want the same data, so
# the result is cached briefly. Emits "status<TAB>rssi<TAB>channel".
scan_wifi() {
  system_profiler SPAirPortDataType -json 2>/dev/null | jq -r '
    (.SPAirPortDataType[0].spairport_airport_interfaces[0] // {}) as $i
    | ($i.spairport_current_network_information // {}) as $c
    | [ ($i.spairport_status_information // "unknown"),
        (($c.spairport_signal_noise // "") | capture("(?<r>-[0-9]+) dBm").r // ""),
        ($c.spairport_network_channel // "") ]
    | @tsv'
}

wifi_state() {
  cache_get "$CACHE" "$CACHE_TTL" && return
  scan_wifi | cache_put "$CACHE" || cat "$CACHE" 2>/dev/null
}

wifi_power() { networksetup -getairportpower "$WIFI_IF" 2>/dev/null | awk '{print $NF}'; }

# Standard mapping: quality = 2 x (RSSI + 100), clamped 0-100, then Omarchy's
# five-step icon ramp. -50 dBm -> 100%, -65 -> 70%, -80 -> 40%.
icon_for_rssi() {
  local quality
  quality=$(echo "${1:--70}" | awk '{ q = 2 * ($1 + 100); if (q < 0) q = 0; if (q > 100) q = 100; printf "%.0f", q }')
  if   [ "$quality" -ge 80 ]; then ICON_OUT="$ICON_WIFI_4"
  elif [ "$quality" -ge 60 ]; then ICON_OUT="$ICON_WIFI_3"
  elif [ "$quality" -ge 40 ]; then ICON_OUT="$ICON_WIFI_2"
  else                             ICON_OUT="$ICON_WIFI_1"; fi
  QUALITY_OUT="$quality"
}

update_bar_item() {
  local item="${NAME:-network}"

  if [ -z "$WIFI_IF" ] || [ "$(wifi_power)" = "Off" ]; then
    sketchybar --set "$item" icon="$ICON_WIFI_OFF" icon.color="$color3" label.drawing=off
    return
  fi

  local status rssi channel
  IFS=$'\t' read -r status rssi channel <<< "$(wifi_state)"

  if [ "$status" != "spairport_status_connected" ]; then
    sketchybar --set "$item" icon="$ICON_WIFI_NOLINK" icon.color="$ITEM_COLOR" label.drawing=off
    return
  fi

  icon_for_rssi "$rssi"
  sketchybar --set "$item" icon="$ICON_OUT" icon.color="$ITEM_COLOR" label.drawing=off
}

populate() {
  ARGS=()
  local power status rssi channel
  power=$(wifi_power)

  if [ "$power" != "On" ]; then
    menu_set network.power "$ICON_WIFI_OFF" "Wi-Fi: Aus" "$color3" "$SELF power on"
    ARGS+=( --set network.hdr.current drawing=off
            --set network.current     drawing=off
            --set network.hdr.known   drawing=off )
    menu_hide_range network.known 0 $((NET_MAX_KNOWN - 1))
    menu_set network.settings "$ICON_SETTINGS" "Wi-Fi Einstellungen…" "$color7" "$SELF settings"
    ARGS+=( --set network.sep drawing=on )
    menu_flush
    return
  fi

  menu_set network.power "$ICON_WIFI_4" "Wi-Fi: An" "$ACCENT_COLOR" "$SELF power off"

  IFS=$'\t' read -r status rssi channel <<< "$(wifi_state)"
  if [ "$status" = "spairport_status_connected" ]; then
    icon_for_rssi "$rssi"
    # No SSID here on purpose -- see the header comment.
    menu_info network.current "$ICON_OUT" "${QUALITY_OUT}% · ${rssi:-?} dBm · ${channel:-?}" "$ACCENT_COLOR"
    ARGS+=( --set network.hdr.current drawing=on )
  else
    ARGS+=( --set network.hdr.current drawing=off --set network.current drawing=off )
  fi

  # Preferred networks: switchable without a password, and the one list macOS
  # still hands over unredacted.
  local i=0 ssid
  while IFS= read -r ssid; do
    [ -z "$ssid" ] && continue
    [ "$i" -ge "$NET_MAX_KNOWN" ] && break
    # A neutral glyph: macOS gives no per-network signal for saved networks,
    # so a strength icon here would be made up.
    menu_set "network.known.$i" "$ICON_NETWORK_SAVED" "$ssid" "$color7" "$SELF connect '$ssid'"
    i=$((i + 1))
  done < <(networksetup -listpreferredwirelessnetworks "$WIFI_IF" 2>/dev/null \
             | tail -n +2 | sed 's/^[[:space:]]*//')

  menu_hide_range network.known "$i" $((NET_MAX_KNOWN - 1))
  if [ "$i" -gt 0 ]; then ARGS+=( --set network.hdr.known drawing=on )
  else                    ARGS+=( --set network.hdr.known drawing=off ); fi

  menu_set network.settings "$ICON_SETTINGS" "Wi-Fi Einstellungen…" "$color7" "$SELF settings"
  ARGS+=( --set network.sep drawing=on )
  menu_flush
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
"power")
  networksetup -setairportpower "$WIFI_IF" "$2" >/dev/null 2>&1
  sleep 1
  cache_drop "$CACHE"
  update_bar_item
  populate
  exit 0
  ;;
"connect")
  # Works without a prompt for a saved network. An unknown one needs the
  # password, which only the settings pane can ask for -- so fall back to it.
  if ! networksetup -setairportnetwork "$WIFI_IF" "$2" >/dev/null 2>&1; then
    menu_close network
    open "x-apple.systempreferences:com.apple.wifi-settings-extension"
    exit 0
  fi
  # Wait for the radio to actually report the new state, so the redrawn menu
  # shows the result rather than the state we started from.
  for _ in 1 2 3 4 5 6 7 8; do
    sleep 0.5
    cache_drop "$CACHE"
    [ "$(wifi_state | cut -f1)" = "spairport_status_connected" ] && break
  done
  update_bar_item
  populate
  exit 0
  ;;
"settings")
  menu_close network
  open "x-apple.systempreferences:com.apple.wifi-settings-extension"
  exit 0
  ;;
esac

case "$SENDER" in
"mouse.exited.global" | "display_change")
  menu_close network
  ;;
"mouse.clicked")
  if menu_is_open network; then
    menu_close network
  else
    menu_open network
    populate
  fi
  ;;
*)
  update_bar_item
  ;;
esac
