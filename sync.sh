#!/usr/bin/env bash
#
# sync.sh -- copy the live configs from ~/.config into this repo.
#
# Run this after changing something locally, then commit. It is a one-way
# copy (system -> repo); install.sh does the opposite direction.
#
#   ./sync.sh            copy and show what changed
#   ./sync.sh --commit   copy, then commit the result
#   ./sync.sh --dry-run  show what would change, copy nothing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$REPO_DIR/config"
SRC="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY_RUN=false
COMMIT=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --commit)  COMMIT=true ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# What we track. Anything not listed here is intentionally left alone.
TRACKED=(
  "aerospace/aerospace.toml"
  "aerospace/scripts"
  "borders/bordersrc"
  "sketchybar/sketchybarrc"
  "sketchybar/colors.sh"
  "sketchybar/variables.sh"
  "sketchybar/lib"
  "sketchybar/items"
  "sketchybar/plugins"
)

# Runtime junk that must never land in the repo.
EXCLUDES=(
  --exclude ".cache"
  --exclude ".DS_Store"
  --exclude "*.log"
)

info() { printf '  %s\n' "$*"; }

echo "==> Syncing $SRC -> $DEST"
$DRY_RUN && echo "    (dry run -- nothing will be written)"

missing=0
for rel in "${TRACKED[@]}"; do
  if [ ! -e "$SRC/$rel" ]; then
    echo "  !! missing on this machine: $SRC/$rel" >&2
    missing=$((missing + 1))
    continue
  fi

  target="$DEST/$rel"
  mkdir -p "$(dirname "$target")"

  if [ -d "$SRC/$rel" ]; then
    # Trailing slashes: copy the CONTENTS of the dir, and --delete so files
    # removed locally also disappear from the repo.
    if $DRY_RUN; then
      rsync -ain --delete "${EXCLUDES[@]}" "$SRC/$rel/" "$target/" | sed 's/^/    /'
    else
      mkdir -p "$target"
      rsync -a --delete "${EXCLUDES[@]}" "$SRC/$rel/" "$target/"
      info "$rel/"
    fi
  else
    if $DRY_RUN; then
      rsync -ain "$SRC/$rel" "$target" | sed 's/^/    /'
    else
      rsync -a "$SRC/$rel" "$target"
      info "$rel"
    fi
  fi
done

[ "$missing" -gt 0 ] && echo "==> $missing tracked path(s) missing -- see above" >&2

$DRY_RUN && exit 0

# Keep every script executable in the repo so a fresh clone works.
find "$DEST" -name "*.sh" -exec chmod +x {} \;
[ -f "$DEST/sketchybar/sketchybarrc" ] && chmod +x "$DEST/sketchybar/sketchybarrc"
[ -f "$DEST/borders/bordersrc" ]       && chmod +x "$DEST/borders/bordersrc"

echo
echo "==> Changes:"
if git -C "$REPO_DIR" diff --quiet && git -C "$REPO_DIR" diff --cached --quiet \
   && [ -z "$(git -C "$REPO_DIR" ls-files --others --exclude-standard)" ]; then
  echo "    none -- repo already matches this machine"
  exit 0
fi
git -C "$REPO_DIR" status --short

if $COMMIT; then
  echo
  git -C "$REPO_DIR" add -A
  git -C "$REPO_DIR" commit -m "sync: configs from $(scutil --get ComputerName 2>/dev/null || hostname -s)"
  echo "==> Committed. Push with: git -C '$REPO_DIR' push"
else
  echo
  echo "==> Review, then:  git -C '$REPO_DIR' add -A && git -C '$REPO_DIR' commit"
fi
