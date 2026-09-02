#!/bin/bash

# Matrix-green palette. Single source of truth for both SketchyBar and
# JankyBorders (~/.config/borders/bordersrc sources this file), so editing
# here recolours the bar, its popups and the window borders together.

export color0=0xff020805   # near-black, faint green cast (bar / background)
export color1=0xff06180f   # slightly lighter dark (item + hover background)
export color2=0xff0a2a18   # mid-dark green
export color3=0xff17694a   # dim green (empty workspaces, section headers)
export color4=0xff00ff9c   # bright accent (borders, highlights, active)
export color5=0xff2bffab   # secondary accent (active workspace label)
export color6=0xff00d98a   # muted accent
export color7=0xff8affc4   # light foreground (inactive-but-present)
export color8=0xff0d3520   # bright-black
export color9=0xff1f8f60   # bright variant of color1
export color10=0xff4dffb4  # bright variant of color2
export color11=0xff80ffcb  # bright variant of color3
export color12=0xff00e5a0  # bright green-cyan
export color13=0xffb3ffdd  # pale green
export color14=0xffd9ffee  # near-white green
export color15=0xffffffff  # white

# -- Special pywal variables --
export background=0xff020805
export foreground=0xff3ddc84
export cursor=0xff00ff9c
export alpha="0"           # transparency (0 = fully opaque)
export wallpaper=""        # filled by pywal at runtime

# -- Named sketchybar aliases (map palette → semantic roles) --

export WHITE=$color1

export BAR_COLOR=$background   # darkest  → bar fill

export TEXT_COLOR=$foreground

export ITEM_BG_COLOR=$color1   # mid-dark → item background
export ITEM_COLOR=$foreground

export ACCENT_COLOR=$color4    # bright   → highlights / icons

# color for items
# Hover borders use the accent so a hovered item is actually visible against
# the near-black bar (the old teal theme used a near-background colour here).
export HIGHLIGHT_BORDER_COLOR=$ACCENT_COLOR
export DEFAULT_BORDER_COLOR=$BAR_COLOR

# -- JankyBorders --
export BORDER_ACTIVE_COLOR=$color4    # focused window  → bright green
export BORDER_INACTIVE_COLOR=0x00000000  # unfocused    → fully transparent (no border)
