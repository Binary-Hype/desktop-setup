#!/bin/bash


# Source Colors
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi
# Source Layout Variables
source "$CONFIG_DIR/variables.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Every `osascript` launch costs ~200ms. The original mute path spent six of
# them per click (~1.4s): read muted, unmute/mute, write or restore a saved
# level, zero the volume, then re-read volume and muted to redraw. This runs
# the mutation AND the read-back in a SINGLE launch.
#
#   $@ = AppleScript statements to run first (may be none, for a plain read)
#   prints "<volume>|<muted>"
audio_apply() {
  osascript "$@" \
    -e 'set s to (get volume settings)' \
    -e 'return ((output volume of s) as text) & "|" & ((output muted of s) as text)'
}

# macOS keeps the output level while muted, so toggling the muted flag alone
# is enough -- no need to zero the volume and stash the old value in a file.
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

# ── Rendering ─────────────────────────────────────────────────────────────────
# Takes the "<volume>|<muted>" pair produced above and draws the item in one
# sketchybar call.

render() {
  local STATE="$1"
  local VOLUME="${STATE%%|*}"
  local MUTED="${STATE##*|}"

  case "$MUTED:$VOLUME" in
    true:*)               ICON="󰝟" ;;
    *:100|*:[6-9][0-9])   ICON="󰕾" ;;
    *:[3-5][0-9])         ICON="󰖀" ;;
    *:[1-2][0-9]|*:[1-9]) ICON="󰕿" ;;
    *)                    ICON="󰝟" ;;
  esac

  sketchybar --set volume icon="$ICON" label="$VOLUME%"
}

# ── Event dispatch ────────────────────────────────────────────────────────────

case "$SENDER" in
"volume_change")
  render "$(audio_apply)"
  ;;
"mouse.scrolled")
  if [[ $SCROLL_DELTA -gt 0 ]]; then
    render "$(volume_step '+ 5')"
  else
    render "$(volume_step '- 5')"
  fi
  ;;
"mouse.clicked")
  render "$(toggle_mute)"
  ;;
*)
  render "$(audio_apply)"
  ;;
esac
