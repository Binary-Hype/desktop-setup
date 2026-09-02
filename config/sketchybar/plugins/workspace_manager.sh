#!/usr/bin/env bash
#
# workspace_manager.sh
#
# Subscribed to the aerospace_workspace_change event.
# On every workspace switch this script:
#   1. Adds bar items for workspaces that appeared since last run
#   2. Removes bar items for workspaces that no longer exist
#   3. Reorders items to match AeroSpace's workspace order
#   4. Updates the visual state (active / has-windows / empty) for every item
#
# Because this is the single source of truth for workspace appearance,
# individual space.* items no longer need their own `script` or subscription.

# Source theme variables (same as sketchybarrc does)
if [ -f "$HOME/.cache/wal/sketchybar_colors.sh" ]; then
    source "$HOME/.cache/wal/sketchybar_colors.sh"
else
    source "$CONFIG_DIR/colors.sh"
fi
source "$CONFIG_DIR/variables.sh"

LOCK="/tmp/sketchybar_wsmgr.$(id -u).lock"

# ── Serialisation ─────────────────────────────────────────────────────────────
# AeroSpace fires this twice for a single switch (on-focus-changed AND
# exec-on-workspace-change), so runs overlap -- and after a wake they arrive in
# a burst. Overlapping runs both removed the same items ("Remove: Item
# 'space.N' not found") and fought over the bar, which read as flicker.
# The loser leaves a marker and exits; the winner does one more pass if a
# marker appeared while it was working.
if ! mkdir "$LOCK" 2>/dev/null; then
    # Clear a lock left behind by a killed run (older than 30s).
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
    local FOCUSED ALL_WORKSPACES CURRENT_ITEMS

    FOCUSED=${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}
    ALL_WORKSPACES=$(aerospace list-workspaces --all 2>/dev/null)

    # AeroSpace does not always answer straight after a wake or a restart.
    # An empty list used to match nothing in the removal loop below, which
    # deleted EVERY space.* item and re-added them a moment later -- the
    # flicker on wake. Leave the bar untouched instead.
    [ -z "$ALL_WORKSPACES" ] && return 0

    CURRENT_ITEMS=$(sketchybar --query bar 2>/dev/null \
                      | jq -r '.items[] | select(startswith("space."))')

    # Everything below is accumulated and sent as ONE sketchybar call, so the
    # bar repaints once instead of once per workspace.
    local ARGS=() WS ITEM WINDOW_COUNT
    local ORDERED=()

    # ── 1. Add workspaces that don't have a bar item yet ─────────────────────
    for WS in $ALL_WORKSPACES; do
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

    # ── 2. Remove items whose workspace no longer exists ─────────────────────
    for ITEM in $CURRENT_ITEMS; do
        WS="${ITEM#space.}"
        if ! echo "$ALL_WORKSPACES" | grep -qx "$WS"; then
            ARGS+=( --remove "$ITEM" )
        fi
    done

    # ── 3. Reorder bar items to match AeroSpace's workspace order ────────────
    ARGS+=( --reorder "${ORDERED[@]}" )

    # ── 4. Update visual state for every workspace item ──────────────────────
    for WS in $ALL_WORKSPACES; do
        ITEM="space.$WS"
        WINDOW_COUNT=$(aerospace list-windows --workspace "$WS" 2>/dev/null | wc -l | tr -d ' ')

        if [ "$WS" = "$FOCUSED" ]; then
            # Fixed width for the active item so the underline centers correctly
            ARGS+=( --set "$ITEM"
                        "label.font=$LABEL_FONT"
                        "label.color=$color5"
                        "label.highlight_color=$ACCENT_COLOR"
                        label.padding_left=0
                        label.padding_right=0
                        "label.drawing=$LABEL_DRAWING"
                        background.drawing=on
                        "background.color=$ACCENT_COLOR"
                        background.height=2
                        background.corner_radius=0
                        background.y_offset=-15
                        width=28
                        padding_left=5
                        padding_right=5 )

        elif [ "$WINDOW_COUNT" -gt 0 ]; then
            # Inactive but has windows -- muted foreground, no underline
            ARGS+=( --set "$ITEM"
                        "label.font=$LABEL_FONT"
                        "label.color=$color7"
                        "label.highlight_color=$ACCENT_COLOR"
                        "label.padding_left=$LABEL_PADDING_LEFT"
                        "label.padding_right=$LABEL_PADDING_RIGHT"
                        "label.drawing=$LABEL_DRAWING"
                        background.drawing=off
                        "padding_left=$ITEM_PADDING_LEFT"
                        "padding_right=$ITEM_PADDING_RIGHT" )
        else
            # Empty workspace -- dimmed, no underline
            ARGS+=( --set "$ITEM"
                        "label.font=$LABEL_FONT"
                        "label.color=$color3"
                        "label.highlight_color=$ACCENT_COLOR"
                        "label.padding_left=$LABEL_PADDING_LEFT"
                        "label.padding_right=$LABEL_PADDING_RIGHT"
                        "label.drawing=$LABEL_DRAWING"
                        background.drawing=off
                        "padding_left=$ITEM_PADDING_LEFT"
                        "padding_right=$ITEM_PADDING_RIGHT" )
        fi
    done

    sketchybar "${ARGS[@]}"
}

render

# If a trigger arrived while we were rendering, fold it into one extra pass
# rather than losing it.
if [ -e "$LOCK/pending" ]; then
    rm -f "$LOCK/pending"
    render
fi
