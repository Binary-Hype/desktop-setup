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

windows() {
  "$AEROSPACE" list-windows --monitor all --app-bundle-id "$APP_ID" --count 2>/dev/null || echo 0
}

# Each aerospace CLI call costs ~34ms, so ask for both facts in one `eval`
# rather than two invocations. Line 1: focused workspace. Line 2: window count.
STATE="$("$AEROSPACE" eval "list-workspaces --focused;          list-windows --monitor all --app-bundle-id $APP_ID --count" 2>/dev/null)"
WS_BEFORE="$(printf '%s\n' "$STATE" | sed -n 1p)"
BEFORE="$(printf '%s\n' "$STATE" | sed -n 2p)"
[ -n "$BEFORE" ] || BEFORE=0

# A window count above zero already proves Warp is running, so there is no need
# for a separate `list-apps` check. (And not pgrep: it cannot see other
# applications' processes from a sandboxed shell and silently reports nothing,
# which used to send this down the wrong branch.)
if [ "$BEFORE" -gt 0 ]; then
  # Fast path: click File > New Window without bringing Warp forward.
  if ! osascript -e "tell application \"System Events\" to tell process \"$APP\" \
        to click menu item \"$MENU_ITEM\" of menu 1 of menu bar item \"File\" of menu bar 1" \
        >/dev/null 2>&1; then
    # Menu layout changed, or the click was refused -- fall back to the old
    # activate-and-type route.
    open -a "$APP"
    sleep 0.25
    osascript -e 'tell application "System Events" to keystroke "n" using command down' 2>/dev/null
  fi
else
  # Not running (or running with no windows): activating opens one by itself.
  open -a "$APP"
fi

# The menu route does not move us, so there is normally nothing to undo and we
# are done here. Only pay for the wait-and-move if focus actually left.
WS_NOW="$("$AEROSPACE" list-workspaces --focused 2>/dev/null)"
[ "$WS_NOW" = "$WS_BEFORE" ] && exit 0

# Focus moved: wait for the new window to exist, then bring it -- and us --
# back to where we started.
for _ in $(seq 1 30); do
  [ "$(windows)" -gt "$BEFORE" ] && break
  sleep 0.1
done

if [ -n "$WS_BEFORE" ]; then
  "$AEROSPACE" move-node-to-workspace "$WS_BEFORE" 2>/dev/null
  "$AEROSPACE" workspace "$WS_BEFORE" 2>/dev/null
fi
