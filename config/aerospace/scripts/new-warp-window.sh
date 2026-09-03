#!/usr/bin/env bash
#
# Open a new Warp window on the workspace that is focused right now.
#
# Warp exposes no scriptable way to create a window:
#   * warp://action/new_window  -- the scheme is registered, `open` returns 0,
#                                  and nothing happens. Warp ignores it.
#   * AppleScript `make new window` -- error -2710; no NSAppleScriptEnabled.
#   * the bundled `oz` CLI      -- drives the Warp agent only, no window verbs.
#   * `open -n -a Warp`         -- does make a window, but starts a SECOND Warp
#                                  instance every time. They stack up.
#
# So we drive its File menu through the Accessibility API. That is ~150ms and,
# unlike activating the app and sending Cmd+N (~670ms), it never focuses Warp's
# existing window -- which is what used to drag AeroSpace onto whatever
# workspace that window lived on.
#
# Requires /usr/bin/osascript to hold Accessibility permission:
#   System Settings > Privacy & Security > Accessibility

set -uo pipefail

APP="Warp"
APP_ID="dev.warp.Warp-Stable"
MENU_ITEM="New Window"
AEROSPACE="$(command -v aerospace || echo /opt/homebrew/bin/aerospace)"

# `open` hands the launched app its caller's environment, and Warp's
# terminal-server then keeps it for the life of the process -- so every tab it
# ever spawns inherits it. When this script runs from inside a Claude Code bash
# call (which is how it gets tested), that means CLAUDE_CODE_CHILD_SESSION=1
# leaks into every future shell, and Claude Code disables transcript saving
# there because it thinks it is a nested session. Strip the markers first.
open_warp() {
  env -u CLAUDE_CODE_CHILD_SESSION \
      -u CLAUDECODE \
      -u CLAUDE_CODE_ENTRYPOINT \
      -u CLAUDE_CODE_EXECPATH \
      -u CLAUDE_CODE_SESSION_ID \
      -u CLAUDE_CODE_MESSAGING_SOCKET \
      -u CLAUDE_CODE_MESSAGING_TOKEN \
      -u CLAUDE_PID \
      -u CLAUDE_EFFORT \
      -u AI_AGENT \
      open -a "$APP"
}

window_ids() {
  "$AEROSPACE" list-windows --monitor all --app-bundle-id "$APP_ID" \
    --format '%{window-id}' 2>/dev/null
}

# Each aerospace CLI call costs ~34ms, so ask for both facts in one `eval`
# rather than two invocations. Line 1: focused workspace. Lines 2+: the window
# ids, diffed later to identify the one we just created.
STATE="$("$AEROSPACE" eval "list-workspaces --focused; list-windows --monitor all --app-bundle-id $APP_ID --format '%{window-id}'" 2>/dev/null)"
WS_BEFORE="$(printf '%s\n' "$STATE" | sed -n 1p)"
IDS_BEFORE="$(printf '%s\n' "$STATE" | sed -n '2,$p')"
BEFORE="$(printf '%s' "$IDS_BEFORE" | grep -c . || true)"

# A window count above zero already proves Warp is running, so there is no need
# for a separate `list-apps` check. (And not pgrep: it cannot see other
# applications' processes from a sandboxed shell and silently reports nothing,
# which used to send this down the wrong branch.)
FELL_BACK=false
if [ "$BEFORE" -gt 0 ]; then
  # Fast path: click File > New Window without bringing Warp forward.
  if ! osascript -e "tell application \"System Events\" to tell process \"$APP\" \
        to click menu item \"$MENU_ITEM\" of menu 1 of menu bar item \"File\" of menu bar 1" \
        >/dev/null 2>&1; then
    # Menu layout changed, or the click was refused -- fall back to the old
    # activate-and-type route.
    FELL_BACK=true
    open_warp
    sleep 0.25
    osascript -e 'tell application "System Events" to keystroke "n" using command down' 2>/dev/null
  fi
else
  # Not running (or running with no windows): activating opens one by itself.
  FELL_BACK=true
  open_warp
fi

# Wait for the new window and work out which one it is. The menu route does not
# bring Warp forward, so without this the window is created unfocused and
# keystrokes keep going to whatever was already in front.
NEW_ID=""
for _ in $(seq 1 40); do
  IDS_NOW="$(window_ids)"
  if [ "$(printf '%s' "$IDS_NOW" | grep -c .)" -gt "$BEFORE" ]; then
    NEW_ID="$(comm -13 <(printf '%s\n' "$IDS_BEFORE" | sort) \
                       <(printf '%s\n' "$IDS_NOW"    | sort) | grep -m1 .)"
    [ -n "$NEW_ID" ] && break
  fi
  sleep 0.02
done

# Only the fallback activates Warp, and only activating can drag us onto the
# workspace its existing window lives on. Skip the query otherwise (~34ms).
WS_NOW="$WS_BEFORE"
$FELL_BACK && WS_NOW="$("$AEROSPACE" list-workspaces --focused 2>/dev/null)"
if [ -n "$WS_BEFORE" ] && [ "$WS_NOW" != "$WS_BEFORE" ]; then
  if [ -n "$NEW_ID" ]; then
    "$AEROSPACE" move-node-to-workspace --window-id "$NEW_ID" "$WS_BEFORE" 2>/dev/null
  else
    "$AEROSPACE" move-node-to-workspace "$WS_BEFORE" 2>/dev/null
  fi
  "$AEROSPACE" workspace "$WS_BEFORE" 2>/dev/null
fi

# Hand the new window keyboard focus.
[ -n "$NEW_ID" ] && "$AEROSPACE" focus --window-id "$NEW_ID" 2>/dev/null
exit 0
