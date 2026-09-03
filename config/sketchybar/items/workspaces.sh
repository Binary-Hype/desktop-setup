#!/bin/bash
#
# Workspace indicators, Omarchy style: the focused workspace shows a dot
# instead of its number, workspaces with windows show their number, empty ones
# are dimmed.
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

