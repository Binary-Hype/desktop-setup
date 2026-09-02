#!/usr/bin/env bash
#
# install.sh -- set up AeroSpace + SketchyBar + JankyBorders on a fresh Mac.
#
# Copies this repo's configs into ~/.config, installs the Homebrew
# dependencies, and starts the services. Existing configs are backed up,
# never overwritten silently.
#
# By default all three components are installed. Select a subset with
# --only / --skip, or by naming components directly:
#
#   ./install.sh                          everything
#   ./install.sh --only sketchybar        just the bar
#   ./install.sh --sketchybar --borders   same as --only sketchybar,borders
#   ./install.sh --skip aerospace         everything except the WM
#   ./install.sh --list                   show components and exit
#
#   --dry-run       print what would happen, change nothing
#   --no-deps       skip Homebrew, only place configs and restart
#   --no-services   place configs but do not start/restart anything

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

ALL_COMPONENTS=(aerospace sketchybar borders)

# Top gap used when AeroSpace is installed without SketchyBar (nothing to
# clear, so it just matches the other outer gaps).
NO_BAR_TOP_GAP=6

DRY_RUN=false
NO_DEPS=false
NO_SERVICES=false
SELECTED=()
SKIPPED=()

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

list_components() {
  cat <<'LIST'
Components:
  aerospace    Tiling window manager (cask: nikitabobko/tap/aerospace)
               config/aerospace/aerospace.toml
  sketchybar   Status bar (formula + JetBrainsMono Nerd Font, blueutil, jq)
               config/sketchybar/
  borders      JankyBorders window outlines (formula)
               config/borders/bordersrc
               Uses sketchybar/colors.sh for its palette when present,
               otherwise the same colours inlined in bordersrc.
LIST
}

is_component() {
  local c
  for c in "${ALL_COMPONENTS[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

# Validate a comma/space separated component list and echo it back.
# NOTE: deliberately avoids bash namerefs (local -n) -- macOS ships bash 3.2,
# where those do not exist, and this script has to run before Homebrew bash.
validate_list() {
  local item out=""
  for item in ${1//,/ }; do
    if ! is_component "$item"; then
      echo "unknown component: $item" >&2
      echo "valid: ${ALL_COMPONENTS[*]}" >&2
      return 1
    fi
    out="$out $item"
  done
  printf '%s' "$out"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)     DRY_RUN=true ;;
    --no-deps)     NO_DEPS=true ;;
    --no-services) NO_SERVICES=true ;;
    --list)        list_components; exit 0 ;;
    --only)        [ $# -ge 2 ] || { echo "--only needs a value" >&2; exit 1; }
                   _v=$(validate_list "$2") || exit 1; SELECTED+=($_v); shift ;;
    --only=*)      _v=$(validate_list "${1#*=}") || exit 1; SELECTED+=($_v) ;;
    --skip)        [ $# -ge 2 ] || { echo "--skip needs a value" >&2; exit 1; }
                   _v=$(validate_list "$2") || exit 1; SKIPPED+=($_v); shift ;;
    --skip=*)      _v=$(validate_list "${1#*=}") || exit 1; SKIPPED+=($_v) ;;
    --aerospace|--sketchybar|--borders)
                   SELECTED+=("${1#--}") ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# Nothing named explicitly -> everything.
[ ${#SELECTED[@]} -eq 0 ] && SELECTED=("${ALL_COMPONENTS[@]}")

# Apply --skip, and de-duplicate while preserving the canonical order.
COMPONENTS=()
for c in "${ALL_COMPONENTS[@]}"; do
  in_selected=false; in_skipped=false
  for s in "${SELECTED[@]}"; do [ "$s" = "$c" ] && in_selected=true; done
  for s in "${SKIPPED[@]+"${SKIPPED[@]}"}"; do [ "$s" = "$c" ] && in_skipped=true; done
  $in_selected && ! $in_skipped && COMPONENTS+=("$c")
done

if [ ${#COMPONENTS[@]} -eq 0 ]; then
  echo "Nothing selected -- every component was skipped." >&2
  exit 1
fi

want() {
  local c
  for c in "${COMPONENTS[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    !! %s\n' "$*" >&2; }
run()  { if $DRY_RUN; then info "would run: $*"; else "$@"; fi; }

[ "$(uname -s)" = "Darwin" ] || { echo "macOS only." >&2; exit 1; }
$DRY_RUN && echo "(dry run -- nothing will be changed)"
echo "Components: ${COMPONENTS[*]}"

# borders prefers sketchybar's colors.sh so the two stay in sync, but falls
# back to the same colours inlined in bordersrc when it is absent.
if want borders && ! want sketchybar && [ ! -f "$DEST/sketchybar/colors.sh" ]; then
  info "No sketchybar/colors.sh here -- borders will use its built-in palette."
fi

brew_tap() {
  if brew tap | grep -qx "$1"; then info "tap $1 (already)"; else run brew tap "$1"; fi
}
brew_formula() {
  local name="${1##*/}"
  if brew list --formula "$name" >/dev/null 2>&1; then info "$name (already)"
  else run brew install "$1"; fi
}
brew_cask() {
  local name="${1##*/}"
  if brew list --cask "$name" >/dev/null 2>&1; then info "$name (already)"
  else run brew install --cask "$1"; fi
}

# ── 1. Dependencies ───────────────────────────────────────────────────────────
if $NO_DEPS; then
  step "Skipping dependencies (--no-deps)"
else
  step "Homebrew dependencies"
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew is not installed. Install it first: https://brew.sh"
    exit 1
  fi

  want aerospace && { brew_tap nikitabobko/tap; brew_cask nikitabobko/tap/aerospace; }

  if want sketchybar || want borders; then
    brew_tap felixkratz/formulae
  fi

  if want sketchybar; then
    brew_formula felixkratz/formulae/sketchybar
    brew_formula blueutil                       # Bluetooth picker
    brew_cask font-jetbrains-mono-nerd-font     # the bar's glyphs
    command -v jq >/dev/null 2>&1 || run brew install jq
  fi

  want borders && brew_formula felixkratz/formulae/borders
fi

# ── 2. Configs ────────────────────────────────────────────────────────────────
step "Installing configs into $DEST"

# AeroSpace refuses to start when both config locations exist.
if want aerospace && [ -e "$HOME/.aerospace.toml" ]; then
  warn "$HOME/.aerospace.toml exists -- AeroSpace errors with 'Ambiguous config'"
  warn "moving it to $HOME/.aerospace.toml.bak-$STAMP"
  run mv "$HOME/.aerospace.toml" "$HOME/.aerospace.toml.bak-$STAMP"
fi

for rel in "${COMPONENTS[@]}"; do
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
  if want sketchybar; then
    find "$DEST/sketchybar" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod +x "$DEST/sketchybar/sketchybarrc" 2>/dev/null || true
  fi
  want borders && chmod +x "$DEST/borders/bordersrc" 2>/dev/null || true
fi

# ── 2b. Adapt gaps.outer.top when there is no bar ─────────────────────────────
# gaps.outer.top reserves vertical room for SketchyBar (BAR_Y_OFFSET +
# BAR_HEIGHT + a small gap). Installed WITHOUT sketchybar, that is ~40pt of
# dead space above every window. Rewrite it to a plain gap in that case.
# The repo copy keeps the bar-aware value, so re-running this with sketchybar
# present restores it.
if want aerospace && [ -f "$DEST/aerospace/aerospace.toml" ]; then
  BAR_PRESENT=false
  want sketchybar && BAR_PRESENT=true
  [ -f "$DEST/sketchybar/variables.sh" ] && BAR_PRESENT=true

  if ! $BAR_PRESENT; then
    step "No SketchyBar on this machine -- adjusting gaps.outer.top"
    info "was: $(grep -m1 '^outer\.top' "$DEST/aerospace/aerospace.toml" || echo '?')"
    info "now: outer.top = $NO_BAR_TOP_GAP (plain gap, no bar to clear)"
    run sed -i '' \
      "s|^outer\.top .*|outer.top        = $NO_BAR_TOP_GAP   # no SketchyBar here -- set by install.sh|" \
      "$DEST/aerospace/aerospace.toml"
  fi
fi

# ── 3. Services ───────────────────────────────────────────────────────────────
if $NO_SERVICES; then
  step "Skipping services (--no-services)"
else
  step "Starting services"
  want sketchybar && run brew services restart sketchybar
  want borders    && run brew services restart borders
  if want aerospace; then
    if [ -d "/Applications/AeroSpace.app" ]; then
      run open -a AeroSpace
      # `open` is a no-op if it is already running, so reload explicitly.
      if ! $DRY_RUN && command -v aerospace >/dev/null 2>&1; then
        sleep 2
        aerospace reload-config >/dev/null 2>&1 && info "reloaded AeroSpace config" || true
      fi
    else
      warn "AeroSpace.app not found in /Applications"
    fi
  fi
fi

# ── 4. Machine-specific values that this script cannot guess ──────────────────
step "Check these -- they are machine-specific"

if want sketchybar; then
  BAR_TOP=$(awk -F= '/^export BAR_Y_OFFSET=/{y=$2} /^export BAR_HEIGHT=/{h=$2} END{print y+h}' \
              "$DEST/sketchybar/variables.sh" 2>/dev/null || echo "?")
  info "SketchyBar occupies the top ${BAR_TOP}pt of the screen."
fi

if want aerospace; then
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
fi

echo
echo "    Manual steps that cannot be scripted:"
want aerospace && cat <<'NOTE'
      * Grant AeroSpace Accessibility permission
        System Settings > Privacy & Security > Accessibility
        AeroSpace cannot start its server without it.
      * aerospace.toml pins monitor names ("built-in") and a per-monitor
        gap tuned for the machine it came from. Adjust for a different setup.
NOTE
want sketchybar && cat <<'NOTE'
      * Auto-hide the macOS menu bar, or the bar will overlap it:
        defaults write NSGlobalDomain _HIHideMenuBar -bool true
      * Auto-hide the Dock, or it eats the bottom gap:
        defaults write com.apple.dock autohide -bool true; killall Dock
      * The Bluetooth picker needs SketchyBar to have Bluetooth access
        (System Settings > Privacy & Security > Bluetooth) -- macOS
        normally prompts on first use.
NOTE
echo

step "Done"
