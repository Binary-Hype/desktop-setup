#!/bin/bash

source "$CONFIG_DIR/lib/common.sh"
source "$CONFIG_DIR/lib/menu.sh"

SELF="$PLUGIN_DIR/volume.sh"
VOL_MAX_DEVICES=8

# Optional: only this tool can switch the output device. Without it the menu
# simply drops its "Ausgabe" section.
AUDIO_SWITCH=$(bin_path SwitchAudioSource)

# ── Audio state ───────────────────────────────────────────────────────────────
# Every `osascript` launch costs ~200ms. The original mute path spent six of
# them per click (~1.4s): read muted, unmute/mute, write or restore a saved
# level, zero the volume, then re-read volume and muted to redraw. This runs the
# mutation AND the read-back in a SINGLE launch.
#
#   $@ = AppleScript statements to run first (may be none, for a plain read)
#   prints "<volume>|<muted>"
audio_apply() {
  osascript "$@" \
    -e 'set s to (get volume settings)' \
    -e 'return ((output volume of s) as text) & "|" & ((output muted of s) as text)'
}

# macOS keeps the output level while muted, so toggling the muted flag alone is
# enough -- no need to zero the volume and stash the old value in a file.
toggle_mute() {
  audio_apply \
    -e 'if output muted of (get volume settings) then' \
    -e '  set volume without output muted' \
    -e 'else' \
    -e '  set volume with output muted' \
    -e 'end if'
}

volume_step() {
  audio_apply -e "set volume output volume ((output volume of (get volume settings)) $1)"
}

icon_for_state() {
  case "$2:$1" in
    true:*)               ICON_OUT="󰝟" ;;
    *:100|*:[6-9][0-9])   ICON_OUT="󰕾" ;;
    *:[3-5][0-9])         ICON_OUT="󰖀" ;;
    *:[1-2][0-9]|*:[1-9]) ICON_OUT="󰕿" ;;
    *)                    ICON_OUT="󰝟" ;;
  esac
}

# Ten blocks, filled to the current level -- the popup's stand-in for a slider.
# Appends with += rather than out="$out█": macOS ships bash 3.2, where the
# latter truncates multi-byte characters to a single byte.
level_bar() {
  local filled=$(( ($1 + 5) / 10 )) i out=""
  [ "$filled" -gt 10 ] && filled=10
  for i in $(seq 1 10); do
    if [ "$i" -le "$filled" ]; then out+="█"; else out+="░"; fi
  done
  printf '%s' "$out"
}

render_bar_item() {
  local volume="${1%%|*}" muted="${1##*|}"
  icon_for_state "$volume" "$muted"
  sketchybar --set volume icon="$ICON_OUT" label.drawing=off
}

populate() {
  local state="${1:-$(audio_apply)}"
  local volume="${state%%|*}" muted="${state##*|}"
  ARGS=()

  icon_for_state "$volume" "$muted"
  menu_set volume.level "$ICON_OUT" "$(level_bar "$volume") ${volume}%" "$ACCENT_COLOR" ""

  if [ "$muted" = "true" ]; then
    menu_set volume.mute "󰕾" "Ton einschalten"  "$ITEM_COLOR" "$SELF mute"
  else
    menu_set volume.mute "󰝟" "Stumm schalten"   "$ITEM_COLOR" "$SELF mute"
  fi

  local i=0
  if [ -n "$AUDIO_SWITCH" ]; then
    local current device icon
    current=$("$AUDIO_SWITCH" -c -t output 2>/dev/null)
    while IFS= read -r device; do
      [ -z "$device" ] && continue
      [ "$i" -ge "$VOL_MAX_DEVICES" ] && break
      case "$(printf '%s' "$device" | tr '[:upper:]' '[:lower:]')" in
        *airpod*|*headphone*|*headset*) icon="󰋋" ;;
        *display*|*monitor*|*hdmi*)     icon="󰍹" ;;
        *) icon="󰓃" ;;
      esac
      if [ "$device" = "$current" ]; then
        menu_set "volume.dev.$i" "$icon" "$device  ✓" "$ACCENT_COLOR" "$SELF output '$device'"
      else
        menu_set "volume.dev.$i" "$icon" "$device"    "$color7"       "$SELF output '$device'"
      fi
      i=$((i + 1))
    done < <("$AUDIO_SWITCH" -a -t output 2>/dev/null)
  fi

  menu_hide_range volume.dev "$i" $((VOL_MAX_DEVICES - 1))
  if [ "$i" -gt 0 ]; then ARGS+=( --set volume.hdr.output drawing=on )
  else                    ARGS+=( --set volume.hdr.output drawing=off ); fi

  menu_set volume.settings "󰒓" "Ton-Einstellungen…" "$color7" "$SELF settings"
  ARGS+=( --set volume.sep drawing=on )
  menu_flush
}

# ── Click and scroll actions ──────────────────────────────────────────────────

case "$1" in
"populate")
  populate
  exit 0
  ;;
"row")
  # The level row: scrolling over it adjusts the volume in place, hovering
  # highlights it like any other row.
  case "$SENDER" in
  "mouse.scrolled")
    if [ "$SCROLL_DELTA" -gt 0 ]; then STATE=$(volume_step '+ 5'); else STATE=$(volume_step '- 5'); fi
    render_bar_item "$STATE"
    populate "$STATE"
    ;;
  "mouse.entered")
    sketchybar --set "$NAME" background.color="$ITEM_BG_COLOR"
    ;;
  "mouse.exited" | "mouse.exited.global")
    sketchybar --set "$NAME" background.color="$MENU_ROW_BG_IDLE"
    ;;
  esac
  exit 0
  ;;
"mute")
  STATE=$(toggle_mute)
  render_bar_item "$STATE"
  populate "$STATE"
  exit 0
  ;;
"output")
  [ -n "$AUDIO_SWITCH" ] && "$AUDIO_SWITCH" -t output -s "$2" >/dev/null 2>&1
  populate
  exit 0
  ;;
"settings")
  menu_close volume
  open "x-apple.systempreferences:com.apple.Sound-Settings.extension"
  exit 0
  ;;
esac

case "$SENDER" in
"display_change" | "space_change")
  menu_close volume
  ;;
"mouse.clicked")
  if menu_is_open volume; then
    menu_close volume
  else
    menu_open volume
    populate
  fi
  ;;
"mouse.scrolled")
  # Scrolling the bar icon keeps working, as before.
  if [ "$SCROLL_DELTA" -gt 0 ]; then STATE=$(volume_step '+ 5'); else STATE=$(volume_step '- 5'); fi
  render_bar_item "$STATE"
  menu_is_open volume && populate "$STATE"
  ;;
*)
  render_bar_item "$(audio_apply)"
  ;;
esac
