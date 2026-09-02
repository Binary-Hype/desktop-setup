#!/bin/bash

sketchybar --add item volume right \
           --set volume script="$PLUGIN_DIR/volume.sh" \
           --set volume updates=on \
           --set volume icon.padding_left=10 \
           --set volume label.padding_right=5 \
           --subscribe volume volume_change  \
           --subscribe volume mouse.scrolled  \
           --subscribe volume mouse.clicked 

