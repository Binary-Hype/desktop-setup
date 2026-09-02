#!/usr/bin/env bash
#
# install.sh -- set up AeroSpace + SketchyBar + JankyBorders on a fresh Mac.
#
# Copies this repo's configs into ~/.config, installs the Homebrew
# dependencies, and starts the services. Existing configs are backed up,
# never overwritten silently.
#
#   ./install.sh              install
#   ./install.sh --no-deps    skip Homebrew, only place configs + restart
#   ./install.sh --dry-run    show what would happen, change nothing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
NO_DEPS=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --no-deps) NO_DEPS=true ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    !! %s\n' "$*" >&2; }
run()  { if $DRY_RUN; then info "would run: $*"; else "$@"; fi; }

[ "$(uname -s)" = "Darwin" ] || { echo "macOS only." >&2; exit 1; }
$DRY_RUN && echo "(dry run -- nothing will be changed)"

# ── 1. Dependencies ───────────────────────────────────────────────────────────
if $NO_DEPS; then
  step "Skipping dependencies (--no-deps)"
else
  step "Homebrew dependencies"
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew is not installed. Install it first: https://brew.sh"
    exit 1
  fi

  for tap in felixkratz/formulae nikitabobko/tap; do
    if brew tap | grep -qx "$tap"; then
      info "tap $tap (already)"
    else
      run brew tap "$tap"
    fi
  done

  # blueutil powers the Bluetooth picker; jq is used by several plugins
  # (macOS ships /usr/bin/jq, so only install it if genuinely absent).
  for f in felixkratz/formulae/sketchybar felixkratz/formulae/borders blueutil; do
    name="${f##*/}"
    if brew list --formula "$name" >/dev/null 2>&1; then
      info "$name (already)"
    else
      run brew install "$f"
    fi
  done
  command -v jq >/dev/null 2>&1 || run brew install jq

  for c in nikitabobko/tap/aerospace font-jetbrains-mono-nerd-font; do
    name="${c##*/}"
    if brew list --cask "$name" >/dev/null 2>&1; then
      info "$name (already)"
    else
      run brew install --cask "$c"
    fi
  done
fi

# ── 2. Configs ────────────────────────────────────────────────────────────────
step "Installing configs into $DEST"

# AeroSpace refuses to start when both config locations exist.
if [ -e "$HOME/.aerospace.toml" ]; then
  warn "$HOME/.aerospace.toml exists -- AeroSpace errors with 'Ambiguous config'"
  warn "moving it to $HOME/.aerospace.toml.bak-$STAMP"
  run mv "$HOME/.aerospace.toml" "$HOME/.aerospace.toml.bak-$STAMP"
fi

for rel in aerospace borders sketchybar; do
  [ -d "$SRC/$rel" ] || { warn "missing in repo: config/$rel -- skipping"; continue; }

  if [ -e "$DEST/$rel" ]; then
    info "backing up existing $rel -> $rel.backup-$STAMP"
    run mv "$DEST/$rel" "$DEST/$rel.backup-$STAMP"
  fi
  run mkdir -p "$DEST/$rel"
  run rsync -a "$SRC/$rel/" "$DEST/$rel/"
  info "installed $rel"
done

if ! $DRY_RUN; then
  find "$DEST/sketchybar" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  chmod +x "$DEST/sketchybar/sketchybarrc" 2>/dev/null || true
  chmod +x "$DEST/borders/bordersrc" 2>/dev/null || true
fi

# ── 3. Services ───────────────────────────────────────────────────────────────
step "Starting services"
run brew services restart sketchybar
run brew services restart borders
if [ -d "/Applications/AeroSpace.app" ]; then
  run open -a AeroSpace
else
  warn "AeroSpace.app not found in /Applications"
fi

# ── 4. Machine-specific values that this script cannot guess ──────────────────
step "Check these -- they are machine-specific"

BAR_TOP=$(awk -F= '/^export BAR_Y_OFFSET=/{y=$2} /^export BAR_HEIGHT=/{h=$2} END{print y+h}' \
            "$DEST/sketchybar/variables.sh" 2>/dev/null || echo "?")
info "SketchyBar occupies the top ${BAR_TOP}pt of the screen."

# gaps.outer.top must clear the bar. On a notched Mac the built-in display's
# usable area already starts below the notch, so it needs a SMALLER value --
# by exactly that inset. Report the real number for this machine.
INSET=$(osascript -l JavaScript -e '
  ObjC.import("AppKit");
  var s = $.NSScreen.screens, out = [];
  for (var i = 0; i < s.count; i++) {
    var d = s.objectAtIndex(i), f = d.frame, vf = d.visibleFrame;
    out.push(d.localizedName.js + "=" + ((f.origin.y + f.size.height) - (vf.origin.y + vf.size.height)));
  }
  out.join("  ");
' 2>/dev/null || echo "unavailable")
info "Per-display top inset (menu bar / notch): $INSET"
info "gaps.outer.top in aerospace.toml must be (bar height + gap) MINUS that inset."

cat <<'NOTES'

    Manual steps that cannot be scripted:
      1. Grant AeroSpace Accessibility permission
         System Settings > Privacy & Security > Accessibility
         AeroSpace cannot start its server without it.
      2. Auto-hide the macOS menu bar, or the bar will overlap it:
         defaults write NSGlobalDomain _HIHideMenuBar -bool true
      3. Auto-hide the Dock, or it eats the bottom gap:
         defaults write com.apple.dock autohide -bool true; killall Dock
      4. The Bluetooth picker needs SketchyBar to have Bluetooth access
         (System Settings > Privacy & Security > Bluetooth) -- macOS
         normally prompts on first use.
      5. aerospace.toml pins monitor names ("built-in") and a per-monitor
         gap tuned for THIS machine. Adjust for a different display setup.

NOTES

step "Done"
NOTES_DONE=1
