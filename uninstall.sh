#!/usr/bin/env bash
#
# uninstall.sh -- remove everything install.sh put on this Mac.
#
# Stops the services, deletes the configs from ~/.config, removes the
# vendored fonts, uninstalls the Homebrew packages and drops the taps that
# existed only for them. The machine is left as if install.sh never ran.
#
# Same component selection as install.sh:
#
#   ./uninstall.sh                        everything
#   ./uninstall.sh --only sketchybar      just the bar
#   ./uninstall.sh --skip aerospace       everything except the WM
#   ./uninstall.sh --list                 show components and exit
#
#   --dry-run          print what would happen, change nothing
#   --yes              skip the confirmation prompt
#   --backup           move configs to a dated folder instead of deleting
#   --keep-deps        leave the Homebrew packages installed
#   --keep-configs     leave ~/.config alone, only stop services and remove deps
#   --keep-fonts       leave the Phosphor fonts in ~/Library/Fonts
#   --include-shared   also remove jq (general-purpose, kept by default)
#   --autoremove       run 'brew autoremove' at the end to drop orphaned deps

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/desktop-setup-removed-$STAMP"

ALL_COMPONENTS=(aerospace sketchybar borders raycast)

DRY_RUN=false
ASSUME_YES=false
BACKUP=false
KEEP_DEPS=false
KEEP_CONFIGS=false
KEEP_FONTS=false
INCLUDE_SHARED=false
AUTOREMOVE=false
SELECTED=()
SKIPPED=()

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; }

list_components() {
  cat <<'LIST'
Components:
  aerospace    Tiling window manager
               cask nikitabobko/tap/aerospace, tap nikitabobko/tap
               ~/.config/aerospace, ~/.aerospace.toml
  sketchybar   Status bar
               formulae sketchybar, blueutil, switchaudio-osx
               cask font-cascadia-code-nf, tap felixkratz/formulae
               ~/.config/sketchybar, ~/Library/Fonts/Phosphor*.ttf
  borders      JankyBorders window outlines
               formula felixkratz/formulae/borders
               ~/.config/borders
  raycast      Launcher
               cask raycast (settings live in your Raycast account)

Kept unless --include-shared:
  jq           general-purpose tool; install.sh only added it if missing
LIST
}

is_component() {
  local c
  for c in "${ALL_COMPONENTS[@]}"; do [ "$c" = "$1" ] && return 0; done
  return 1
}

# Same validation as install.sh. No bash namerefs -- macOS ships bash 3.2.
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
    --dry-run)        DRY_RUN=true ;;
    --yes|-y)         ASSUME_YES=true ;;
    --backup)         BACKUP=true ;;
    --keep-deps)      KEEP_DEPS=true ;;
    --keep-configs)   KEEP_CONFIGS=true ;;
    --keep-fonts)     KEEP_FONTS=true ;;
    --include-shared) INCLUDE_SHARED=true ;;
    --autoremove)     AUTOREMOVE=true ;;
    --list)           list_components; exit 0 ;;
    --only)           [ $# -ge 2 ] || { echo "--only needs a value" >&2; exit 1; }
                      _v=$(validate_list "$2") || exit 1; SELECTED+=($_v); shift ;;
    --only=*)         _v=$(validate_list "${1#*=}") || exit 1; SELECTED+=($_v) ;;
    --skip)           [ $# -ge 2 ] || { echo "--skip needs a value" >&2; exit 1; }
                      _v=$(validate_list "$2") || exit 1; SKIPPED+=($_v); shift ;;
    --skip=*)         _v=$(validate_list "${1#*=}") || exit 1; SKIPPED+=($_v) ;;
    --aerospace|--sketchybar|--borders|--raycast)
                      SELECTED+=("${1#--}") ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
  esac
  shift
done

[ ${#SELECTED[@]} -eq 0 ] && SELECTED=("${ALL_COMPONENTS[@]}")

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

has_config() {
  case "$1" in
    aerospace|sketchybar|borders) return 0 ;;
    *) return 1 ;;
  esac
}

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    !! %s\n' "$*" >&2; }
run()  { if $DRY_RUN; then info "would run: $*"; else "$@"; fi; }

# Is the component's app/binary still on this Mac?
#
# Preferences and support folders are only safe to delete once the thing that
# owns them is actually gone. Anything installed outside Homebrew survives the
# uninstall step above, and wiping its settings while the app stays behind
# would be destroying data this script never installed.
app_present() {
  case "$1" in
    aerospace)  [ -d "/Applications/AeroSpace.app" ] ;;
    raycast)    [ -d "/Applications/Raycast.app" ] ;;
    sketchybar) command -v sketchybar >/dev/null 2>&1 ;;
    borders)    command -v borders    >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Same reasoning as install.sh: keep Claude Code's session markers out of
# anything this script launches or talks to.
no_claude_env() {
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
      "$@"
}

# Delete, or move into the backup folder when --backup is set.
#
# Reports in its own right rather than going through run(), so a dry run says
# "would remove" instead of printing a "would run" line followed by a past
# tense one. Reading a preview that claims it deleted your files is alarming
# in exactly the situation where you most need to trust the output.
remove_path() {
  local p="$1"
  [ -e "$p" ] || return 0
  if $BACKUP; then
    if $DRY_RUN; then info "would move $p -> $BACKUP_DIR/"; return 0; fi
    mkdir -p "$BACKUP_DIR"
    mv "$p" "$BACKUP_DIR/"
    info "moved $p -> $BACKUP_DIR/"
  else
    if $DRY_RUN; then info "would remove $p"; return 0; fi
    rm -rf "$p"
    info "removed $p"
  fi
}

[ "$(uname -s)" = "Darwin" ] || { echo "macOS only." >&2; exit 1; }

HAVE_BREW=false
command -v brew >/dev/null 2>&1 && HAVE_BREW=true

# ── What is actually here ─────────────────────────────────────────────────────
# Report before asking, so the confirmation is informed rather than blind.
step "Planned removal"
$DRY_RUN && info "(dry run -- nothing will be changed)"
info "Components: ${COMPONENTS[*]}"
if $BACKUP; then
  info "Configs will be MOVED to $BACKUP_DIR"
else
  info "Configs will be DELETED"
fi
$KEEP_CONFIGS && info "--keep-configs: ~/.config untouched"
$KEEP_DEPS    && info "--keep-deps: Homebrew packages kept"
$KEEP_FONTS   && info "--keep-fonts: Phosphor fonts kept"

if ! $ASSUME_YES && ! $DRY_RUN; then
  echo
  printf '    This cannot be undone. Type yes to continue: '
  read -r reply
  [ "$reply" = "yes" ] || { echo "    Aborted."; exit 1; }
fi

# ── Raycast is opt-in, and only when Homebrew owns it ─────────────────────────
# Raycast is a general launcher people install for its own sake, not a piece of
# this setup -- install.sh only ever adds the app, since its settings live in
# your Raycast account. So it gets its own confirmation, and a copy installed
# outside Homebrew is left completely alone: this script did not put it there
# and must not take it away.
REMOVE_RAYCAST=false
if want raycast; then
  if ! $HAVE_BREW || ! brew list --cask raycast >/dev/null 2>&1; then
    if app_present raycast; then
      step "Leaving Raycast alone"
      info "Raycast.app is installed, but not as a Homebrew cask."
      info "This script only removes what it installed -- skipping it entirely."
    fi
  elif $ASSUME_YES; then
    REMOVE_RAYCAST=true
  elif $DRY_RUN; then
    REMOVE_RAYCAST=true
    info "(dry run assumes yes for Raycast)"
  else
    echo
    printf '    Also remove Raycast and its settings? [y/N]: '
    read -r reply
    case "$reply" in
      [yY]|[yY][eE][sS]) REMOVE_RAYCAST=true ;;
      *) info "Keeping Raycast." ;;
    esac
  fi
fi

# ── 1. Services and apps ──────────────────────────────────────────────────────
step "Stopping services"
if $HAVE_BREW; then
  if want sketchybar && brew list --formula sketchybar >/dev/null 2>&1; then
    run no_claude_env brew services stop sketchybar
  fi
  if want borders && brew list --formula borders >/dev/null 2>&1; then
    run no_claude_env brew services stop borders
  fi
else
  info "no brew -- skipping service stop"
fi

# AeroSpace has no brew service; it is a normal app. Ask it to quit cleanly
# first, since killing it leaves windows in whatever layout it had.
if want aerospace && pgrep -qx AeroSpace 2>/dev/null; then
  if command -v aerospace >/dev/null 2>&1; then
    run no_claude_env aerospace enable off
  fi
  run osascript -e 'tell application "AeroSpace" to quit'
fi
if $REMOVE_RAYCAST && pgrep -qx Raycast 2>/dev/null; then
  run osascript -e 'tell application "Raycast" to quit'
fi

# ── 2. Homebrew packages ──────────────────────────────────────────────────────
if $KEEP_DEPS; then
  step "Keeping Homebrew packages (--keep-deps)"
elif ! $HAVE_BREW; then
  step "Homebrew not installed -- nothing to uninstall"
else
  step "Uninstalling Homebrew packages"

  drop_formula() {
    if brew list --formula "$1" >/dev/null 2>&1; then
      run no_claude_env brew uninstall "$1" || warn "$1: uninstall failed (something depends on it?)"
    else
      info "$1 (not installed)"
    fi
  }
  # --zap also clears the cask's preferences and support files, which is what
  # makes this a clean removal rather than just deleting the .app.
  drop_cask() {
    if brew list --cask "$1" >/dev/null 2>&1; then
      run no_claude_env brew uninstall --zap --cask "$1" || warn "$1: uninstall failed"
    else
      info "$1 (not installed)"
    fi
  }

  if want aerospace; then drop_cask aerospace; fi

  if want sketchybar; then
    drop_formula sketchybar
    drop_formula blueutil
    drop_formula switchaudio-osx
    drop_cask font-cascadia-code-nf
    if $INCLUDE_SHARED; then
      drop_formula jq
    elif brew list --formula jq >/dev/null 2>&1; then
      info "jq kept -- general-purpose tool, pass --include-shared to remove"
    fi
  fi

  if want borders; then drop_formula borders; fi
  if $REMOVE_RAYCAST; then drop_cask raycast; fi

  # ── Taps ──
  # Only untap once nothing installed still comes from that tap; another
  # project may well be using it.
  step "Dropping taps that are now unused"
  # $2.. are the packages this run removes from the tap. A dry run has not
  # actually uninstalled them yet, so they must be discounted here or every tap
  # looks busy and the preview claims it would keep taps a real run drops.
  drop_tap() {
    local tap="$1" remaining pkg
    shift
    brew tap | grep -qx "$tap" || { info "$tap (not tapped)"; return 0; }
    remaining=$(brew list --full-name 2>/dev/null | grep "^$tap/" || true)
    for pkg in "$@"; do
      remaining=$(printf '%s\n' "$remaining" | grep -v "^$tap/$pkg\$" || true)
    done
    remaining=$(printf '%s' "$remaining" | grep -c . || true)
    if [ "$remaining" -gt 0 ]; then
      info "$tap kept -- $remaining package(s) from it still installed"
    else
      run no_claude_env brew untap "$tap"
    fi
  }
  if want aerospace; then drop_tap nikitabobko/tap aerospace; fi
  if want sketchybar && want borders; then
    drop_tap felixkratz/formulae sketchybar borders
  elif want sketchybar; then
    drop_tap felixkratz/formulae sketchybar
  elif want borders; then
    drop_tap felixkratz/formulae borders
  fi
fi

# ── 3. Configs ────────────────────────────────────────────────────────────────
if $KEEP_CONFIGS; then
  step "Keeping configs (--keep-configs)"
else
  step "Removing configs from $DEST"
  for rel in "${COMPONENTS[@]}"; do
    has_config "$rel" || { info "$rel: app only, no config to remove"; continue; }
    if [ -e "$DEST/$rel" ]; then
      remove_path "$DEST/$rel"
    else
      info "$rel (not present)"
    fi
    # install.sh parks the previous config next to it as <name>.backup-STAMP.
    # Those are ours too, so a clean uninstall takes them with it.
    for old in "$DEST/$rel".backup-*; do
      [ -e "$old" ] || continue
      remove_path "$old"
    done
  done

  # The alternate AeroSpace config location, plus the copies install.sh moved
  # aside to avoid its "Ambiguous config" error.
  if want aerospace; then
    [ -e "$HOME/.aerospace.toml" ] && remove_path "$HOME/.aerospace.toml"
    for old in "$HOME"/.aerospace.toml.bak-*; do
      [ -e "$old" ] || continue
      remove_path "$old"
    done
  fi
fi

# ── 4. Fonts ──────────────────────────────────────────────────────────────────
# Phosphor is vendored in this repo and copied into the user font directory,
# so it has no Homebrew entry to uninstall. Cascadia Code NF came from a cask
# and was handled above.
if want sketchybar && ! $KEEP_FONTS; then
  step "Removing Phosphor fonts from ~/Library/Fonts"
  found=false
  for f in "$HOME"/Library/Fonts/Phosphor*.ttf; do
    [ -e "$f" ] || continue
    found=true
    remove_path "$f"
  done
  $found || info "none present"
fi

# ── 5. Leftovers ──────────────────────────────────────────────────────────────
# brew services normally removes its own launch agent on uninstall, but a stale
# plist survives if the formula was already gone. Preferences are written by the
# apps at runtime, so they outlive an uninstall unless removed here.
if ! $KEEP_CONFIGS; then
  step "Clearing leftovers"

  # Only clear a component's settings once its app is actually gone. With
  # --keep-deps the app stays, so its preferences are still live data. A dry
  # run reports what a real run would reach, so it assumes the uninstall above
  # succeeded rather than reading the still-installed state.
  purge_ok() {
    $KEEP_DEPS && return 1
    $DRY_RUN && return 0
    ! app_present "$1"
  }

  LEFTOVERS=()
  if want sketchybar && purge_ok sketchybar; then
    LEFTOVERS+=("$HOME/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist")
    LEFTOVERS+=("$HOME/.cache/wal/sketchybar_colors.sh")
  fi
  if want borders && purge_ok borders; then
    LEFTOVERS+=("$HOME/Library/LaunchAgents/homebrew.mxcl.borders.plist")
  fi
  if want aerospace && purge_ok aerospace; then
    LEFTOVERS+=("$HOME/Library/Preferences/bobko.aerospace.plist")
    LEFTOVERS+=("$HOME/Library/Application Support/AeroSpace")
    LEFTOVERS+=("$HOME/Library/Caches/bobko.aerospace")
    LEFTOVERS+=("$HOME/Library/Saved Application State/bobko.aerospace.savedState")
  fi
  if $REMOVE_RAYCAST && purge_ok raycast; then
    LEFTOVERS+=("$HOME/Library/Preferences/com.raycast.macos.plist")
    LEFTOVERS+=("$HOME/Library/Application Support/com.raycast.macos")
    LEFTOVERS+=("$HOME/Library/Caches/com.raycast.macos")
  fi

  any=false
  for p in "${LEFTOVERS[@]+"${LEFTOVERS[@]}"}"; do
    [ -e "$p" ] || continue
    any=true
    remove_path "$p"
  done
  $any || info "none found"

  # macOS caches font data; without this the removed glyphs can linger in
  # already-running apps until the next login.
  if want sketchybar && ! $KEEP_FONTS && ! $DRY_RUN; then
    atsutil databases -remove >/dev/null 2>&1 || true
    info "flushed the font cache"
  fi
fi

if $AUTOREMOVE && $HAVE_BREW && ! $KEEP_DEPS; then
  step "Removing orphaned Homebrew dependencies"
  warn "this also drops orphans left by other projects"
  run no_claude_env brew autoremove
fi

# ── 6. What is left for you ───────────────────────────────────────────────────
step "Done"

if $BACKUP && [ -d "$BACKUP_DIR" ]; then
  info "Your configs are in $BACKUP_DIR"
fi

echo
echo "    Not scripted -- do these by hand if you want them back:"
want sketchybar && cat <<'NOTE'
      * Re-show the macOS menu bar and Dock if install.sh's notes had you
        hide them:
          defaults write NSGlobalDomain _HIHideMenuBar -bool false
          defaults write com.apple.dock autohide -bool false; killall Dock
NOTE
want aerospace && cat <<'NOTE'
      * Remove AeroSpace's stale Accessibility entry:
        System Settings > Privacy & Security > Accessibility
      * Your windows keep whatever positions AeroSpace last gave them.
NOTE
$REMOVE_RAYCAST && cat <<'NOTE'
      * Raycast settings live in your Raycast account, not on this Mac.
        Restore Spotlight's hotkey under Keyboard > Keyboard Shortcuts.
NOTE
cat <<'NOTE'
      * Homebrew itself is left installed.
      * This repo is untouched -- delete the clone yourself if you are done.
NOTE
echo
