#!/usr/bin/env bash
#
# Open a new Warp window on the workspace that is focused right now.
#
# Warp cannot be asked for a window any other way:
#   * warp://action/new_window  -- the scheme is registered, `open` returns 0,
#                                  and nothing happens. Warp ignores it.
#   * AppleScript `make new window` -- error -2710; no NSAppleScriptEnabled.
#   * the bundled `oz` CLI      -- drives the Warp agent only, no window verbs.
#   * `open -n -a Warp`         -- does make a window, but starts a SECOND Warp
#                                  instance every time. They stack up.
# So: activate it and send Cmd+N.
#
# Activating Warp focuses its existing window, which may sit on another
# workspace and drags AeroSpace's focus along with it -- hence recording the
# workspace up front and moving the new window back afterwards.
#
# Requires /usr/bin/osascript to hold Accessibility permission:
#   System Settings > Privacy & Security > Accessibility

set -uo pipefail

APP="Warp"
APP_ID="dev.warp.Warp-Stable"
AEROSPACE="$(command -v aerospace || echo /opt/homebrew/bin/aerospace)"

windows() {
  "$AEROSPACE" list-windows --monitor all --app-bundle-id "$APP_ID" --count 2>/dev/null || echo 0
}

WS_BEFORE="$("$AEROSPACE" list-workspaces --focused 2>/dev/null)"
BEFORE="$(windows)"

# Is Warp already up with a window? Ask AeroSpace, not pgrep: pgrep cannot see
# other applications' processes from a sandboxed shell and silently reports
# nothing, which sent this down the wrong branch.
RUNNING=false
"$AEROSPACE" list-apps 2>/dev/null | grep -q "$APP_ID" && RUNNING=true

if $RUNNING && [ "$BEFORE" -gt 0 ]; then
  open -a "$APP"
  sleep 0.25   # let it come forward, or the keystroke is dropped
  osascript -e 'tell application "System Events" to keystroke "n" using command down' 2>/dev/null
else
  # Not running (or running with no windows): activating opens one by itself.
  open -a "$APP"
fi

# Wait for the window to actually exist before moving anything (~3s max).
for _ in $(seq 1 30); do
  [ "$(windows)" -gt "$BEFORE" ] && break
  sleep 0.1
done

# The new window has focus; bring it -- and us -- back to where we started.
if [ -n "$WS_BEFORE" ]; then
  "$AEROSPACE" move-node-to-workspace "$WS_BEFORE" 2>/dev/null
  "$AEROSPACE" workspace "$WS_BEFORE" 2>/dev/null
fi
