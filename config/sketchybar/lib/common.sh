#!/bin/bash
#
# Sourced by every item and plugin. Loads the palette and the geometry, and
# provides the two helpers that would otherwise be re-implemented per module.

# pywal writes a generated palette here when it is in use; colors.sh is the
# checked-in fallback and the normal case on this machine.
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi
source "$CONFIG_DIR/variables.sh"

PLUGIN_DIR="$CONFIG_DIR/plugins"
ITEM_DIR="$CONFIG_DIR/items"
LIB_DIR="$CONFIG_DIR/lib"

# Resolve a Homebrew binary. sketchybar runs under launchd, whose PATH does not
# reliably contain either Homebrew prefix, so `command -v` alone is not enough.
# Prints nothing and returns 1 when the tool is absent -- callers degrade.
bin_path() {
  local found
  found=$(command -v "$1" 2>/dev/null)
  if [ -x "$found" ]; then printf '%s' "$found"; return 0; fi
  local candidate
  for candidate in "/opt/homebrew/bin/$1" "/usr/local/bin/$1"; do
    if [ -x "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  done
  return 1
}

# cache_get FILE TTL -- print the cached payload if it is younger than TTL
# seconds, else fail. Used for the expensive system_profiler scans, which both
# the bar item and the popup want at the same moment.
cache_get() {
  local file="$1" ttl="$2" age
  [ -s "$file" ] || return 1
  age=$(( $(date +%s) - $(stat -f %m "$file" 2>/dev/null || echo 0) ))
  [ "$age" -lt "$ttl" ] || return 1
  cat "$file"
}

# cache_put FILE < payload -- replace the cache atomically, but ONLY with a
# non-empty payload. A scan can come back empty right after a wake; overwriting
# good data with that is what made items blank out and reappear.
cache_put() {
  local file="$1" payload
  payload=$(cat)
  [ -n "$payload" ] || return 1
  printf '%s\n' "$payload" > "$file.tmp.$$" && mv -f "$file.tmp.$$" "$file"
  printf '%s\n' "$payload"
}

cache_drop() { rm -f "$1"; }
