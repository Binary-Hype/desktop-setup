#!/bin/bash
#
# Workspace indicators, Omarchy style: the focused workspace shows a dot
# instead of its number, workspaces with windows show their number, empty ones
# are dimmed.
#
# Each workspace is drawn only on the bar of the monitor it currently sits on,
# so every screen shows its own workspaces (see display_of in the plugin). The
# workspace visible on a screen that does not have the focus keeps the dot, but
# without the accent colour.
#
# There are no per-workspace scripts. One hidden manager item subscribes to the
# AeroSpace event and drives every space.* item, because workspaces come and go
# at runtime and their styling has to stay consistent in a single pass.

sketchybar --add item workspaces left \
           --set workspaces \
               drawing=off \
               updates=on \
               script="$PLUGIN_DIR/workspaces.sh" \
           --subscribe workspaces aerospace_workspace_change

