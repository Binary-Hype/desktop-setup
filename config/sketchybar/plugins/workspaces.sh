#!/usr/bin/env bash
#
# Single source of truth for every space.* item: adds workspaces that appeared,
# removes those that vanished, reorders them to AeroSpace's order and restyles
# them -- all in one batched sketchybar call.

source "$CONFIG_DIR/lib/common.sh"

LOCK="/tmp/sketchybar_ws.$(id -u).lock"

# ── Serialisation ─────────────────────────────────────────────────────────────
# AeroSpace fires this twice for a single switch (on-focus-changed AND
# exec-on-workspace-change), so runs overlap -- and after a wake they arrive in
# a burst. Overlapping runs both removed the same items and fought over the bar,
# which read as flicker. The loser leaves a marker and exits; the winner does
# one more pass if a marker appeared while it was working.
if ! mkdir "$LOCK" 2>/dev/null; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -gt 30 ]; then
        rm -rf "$LOCK"
    else
        touch "$LOCK/pending" 2>/dev/null
        exit 0
    fi
    mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCK"' EXIT

render() {
    local FOCUSED LIVE ALL CURRENT_ITEMS

    FOCUSED=${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}
    LIVE=$(aerospace list-workspaces --all 2>/dev/null)

    # AeroSpace does not always answer straight after a wake or a restart. An
    # empty list matches nothing in the removal loop below, which used to
    # delete EVERY space.* item and re-add them a moment later -- the flicker on
    # wake. Leave the bar untouched instead.
    [ -z "$LIVE" ] && return 0

    # Omarchy pins workspaces 1-5 with persistent-workspaces. AeroSpace has no
    # such option, so union its live list with ours and sort numerically.
    ALL=$(printf '%s\n%s\n' "$LIVE" "$(printf '%s\n' $WS_PERSISTENT)" \
            | sort -u -k1,1 -V)

    CURRENT_ITEMS=$(sketchybar --query bar 2>/dev/null \
                      | jq -r '.items[] | select(startswith("space."))')

    local ARGS=() WS ITEM WINDOWS
    local ORDERED=()

    # ── 1. Add workspaces that have no bar item yet ──────────────────────────
    for WS in $ALL; do
        ITEM="space.$WS"
        ORDERED+=("$ITEM")
        if ! echo "$CURRENT_ITEMS" | grep -qx "$ITEM"; then
            ARGS+=( --add item "$ITEM" left
                    --set "$ITEM"
                        "label=$WS"
                        label.align=center
                        label.width=dynamic
                        background.drawing=off
                        "click_script=aerospace workspace $WS" )
        fi
    done

    # ── 2. Remove items whose workspace is gone (persistent ones stay) ───────
    for ITEM in $CURRENT_ITEMS; do
        WS="${ITEM#space.}"
        if ! echo "$ALL" | grep -qx "$WS"; then
            ARGS+=( --remove "$ITEM" )
        fi
    done

    # ── 3. Match AeroSpace's order ───────────────────────────────────────────
    ARGS+=( --reorder "${ORDERED[@]}" )

    # ── 4. Style: focused = dot, has windows = number, empty = dimmed ────────
    for WS in $ALL; do
        ITEM="space.$WS"
        WINDOWS=$(aerospace list-windows --workspace "$WS" 2>/dev/null | wc -l | tr -d ' ')

        if [ "$WS" = "$FOCUSED" ]; then
            ARGS+=( --set "$ITEM" "label=$WS_ACTIVE_GLYPH" "label.color=$ACCENT_COLOR" )
        elif [ "$WINDOWS" -gt 0 ]; then
            ARGS+=( --set "$ITEM" "label=$WS" "label.color=$color7" )
        else
            # Omarchy: #workspaces button.empty { opacity: 0.5 }
            ARGS+=( --set "$ITEM" "label=$WS" "label.color=$color3" )
        fi

        ARGS+=( --set "$ITEM"
                    "label.font=$LABEL_FONT"
                    "label.padding_left=$WS_LABEL_PADDING"
                    "label.padding_right=$WS_LABEL_PADDING"
                    "padding_left=$WS_ITEM_PADDING"
                    "padding_right=$WS_ITEM_PADDING" )
    done

    sketchybar "${ARGS[@]}"
}

render

# Fold a trigger that arrived mid-render into one extra pass rather than losing it.
if [ -e "$LOCK/pending" ]; then
    rm -f "$LOCK/pending"
    render
fi
