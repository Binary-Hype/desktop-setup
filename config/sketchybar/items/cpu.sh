#!/bin/bash

sketchybar --add item cpu right \
           --set cpu  update_freq=2 \
                      icon=󰍛  \
                      label.width=40 \
                      script="$PLUGIN_DIR/cpu.sh" \
           --subscribe cpu mouse.clicked
