#!/bin/bash

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/battery.sh"

# Omarchy's icon ramps (format-icons in config.jsonc), ten steps each.
BAT_DISCHARGING=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
BAT_CHARGING=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)

# Fills PERCENT / STATE / REMAINING from a single pmset call -- `pmset -g batt`
# is slow enough that asking it twice per redraw is noticeable.
read_battery() {
  local batt line
  batt=$(pmset -g batt 2>/dev/null)
  line=$(printf '%s' "$batt" | grep -m1 'InternalBattery')
  PERCENT=$(printf '%s' "$line" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
  REMAINING=$(printf '%s' "$line" | grep -Eo '[0-9]+:[0-9]{2}' | head -1)
  [ "$REMAINING" = "0:00" ] && REMAINING=""
  # Order matters: pmset says "discharging", which also matches *charging*.
  case "$line" in
    *discharging*) STATE=discharging ;;
    *charged*)     STATE=charged ;;
    *charging*)    STATE=charging ;;
    *)             STATE=discharging ;;
  esac
}

# Sets ICON_OUT rather than echoing -- this runs on every redraw.
battery_icon() {
  local step=$(( ${PERCENT:-0} / 10 ))
  [ "$step" -gt 9 ] && step=9
  if [ "$STATE" = "discharging" ]; then
    ICON_OUT="${BAT_DISCHARGING[$step]}"
  else
    ICON_OUT="${BAT_CHARGING[$step]}"
  fi
}

update_bar_item() {
  read_battery
  [ -z "$PERCENT" ] && return
  battery_icon
  # Omarchy: states { warning: 20, critical: 10 }
  local color="$ITEM_COLOR"
  [ "$PERCENT" -le 20 ] && color="$color7"
  [ "$PERCENT" -le 10 ] && color="$ACCENT_COLOR"
  sketchybar --set "${NAME:-battery}" icon="$ICON_OUT" icon.color="$color" label.drawing=off
}

populate() {
  read_battery
  battery_icon

  local lpm lpm_state source_text
  lpm=$(pmset -g 2>/dev/null | awk '/lowpowermode/{print $2}')
  [ "$lpm" = "1" ] && lpm_state="An" || lpm_state="Aus"

  case "$STATE" in
    charged)  source_text="Netzteil · geladen" ;;
    charging) source_text="Netzteil${REMAINING:+ · voll in $REMAINING}" ;;
    *)        source_text="Akku${REMAINING:+ · noch $REMAINING}" ;;
  esac

  menu_info battery.charge "$ICON_OUT" "${PERCENT:-?} %" "$ACCENT_COLOR"
  menu_info battery.source ""          "$source_text"    "$ITEM_COLOR"
  # Toggling low power mode needs sudo, so this line reports rather than acts.
  menu_info battery.lpm    ""          "Energiesparmodus: $lpm_state" "$color7"

  menu_set battery.lock     "󰌾" "Bildschirm sperren" "$ITEM_COLOR" "$SELF power lock"
  menu_set battery.sleep    "󰒲" "Ruhezustand"        "$ITEM_COLOR" "$SELF power sleep"
  # These two do NOT ask for confirmation, hence the ellipsis and the separator
  # keeping them away from the rest.
  menu_set battery.restart  "󰜉" "Neu starten…"       "$ITEM_COLOR" "$SELF power restart"
  menu_set battery.shutdown "󰐥" "Ausschalten…"       "$ITEM_COLOR" "$SELF power shutdown"

  menu_set battery.settings "󰒓" "Batterie-Einstellungen…" "$color7" "$SELF settings"

  ARGS+=( --set battery.sep1 drawing=on --set battery.sep2 drawing=on )
  menu_flush
}

case "$1" in
"populate")
  populate
  exit 0
  ;;
"power")
  menu_close battery
  case "$2" in
    lock)     pmset displaysleepnow ;;
    sleep)    osascript -e 'tell application "System Events" to sleep' ;;
    restart)  osascript -e 'tell application "System Events" to restart' ;;
    shutdown) osascript -e 'tell application "System Events" to shut down' ;;
  esac
  exit 0
  ;;
"settings")
  menu_close battery
  open "x-apple.systempreferences:com.apple.preference.battery"
  exit 0
  ;;
esac

case "$SENDER" in
"mouse.exited.global" | "display_change")
  menu_close battery
  ;;
"mouse.clicked")
  if menu_is_open battery; then
    menu_close battery
  else
    menu_open battery
    populate
  fi
  ;;
*)
  update_bar_item
  ;;
esac
