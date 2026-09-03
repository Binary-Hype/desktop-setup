#!/bin/bash
#
# Every glyph the bar draws, named. Icons come from Phosphor
# (https://phosphoricons.com, MIT) -- the fonts live in fonts/ and are
# installed into ~/Library/Fonts by install.sh.
#
# The comment after each line is the Phosphor icon name, so a glyph can be
# looked up on the site without decoding the codepoint.

# -- Bar modules ---------------------------------------------------------------
export ICON_LOGO=""             # apple-logo
export ICON_BT=""               # bluetooth
export ICON_BT_CONNECTED=""     # bluetooth-connected
export ICON_BT_OFF=""           # bluetooth-slash
export ICON_WIFI_4=""           # wifi-high
export ICON_WIFI_3=""           # wifi-medium
export ICON_WIFI_2=""           # wifi-low
export ICON_WIFI_1=""           # wifi-none
export ICON_WIFI_OFF=""         # wifi-slash
export ICON_WIFI_NOLINK=""      # wifi-x
export ICON_VOL_HIGH=""         # speaker-high
export ICON_VOL_LOW=""          # speaker-low
export ICON_VOL_NONE=""         # speaker-none
export ICON_VOL_MUTED=""        # speaker-slash
export ICON_CPU=""              # cpu
export ICON_RAM=""              # memory
export ICON_UPTIME=""           # clock

# -- Battery -- Phosphor has five steps, not ten -------------------------------
export ICON_BAT_0=""            # battery-empty
export ICON_BAT_1=""            # battery-low
export ICON_BAT_2=""            # battery-medium
export ICON_BAT_3=""            # battery-high
export ICON_BAT_4=""            # battery-full
export ICON_BAT_CHARGING=""     # battery-charging

# -- Menu actions --------------------------------------------------------------
export ICON_SETTINGS=""          # gear
export ICON_LOCK=""              # lock-key
export ICON_SLEEP=""             # moon
export ICON_RESTART=""           # arrow-clockwise
export ICON_POWER=""             # power
export ICON_APPS=""              # magnifying-glass
export ICON_SCREENSHOT=""        # camera
export ICON_RELOAD=""            # arrow-clockwise
export ICON_NETWORK_SAVED=""     # globe-simple

# -- Devices -------------------------------------------------------------------
export ICON_DEV_HEADPHONES=""     # headphones
export ICON_DEV_SPEAKER=""        # speaker-hifi
export ICON_DEV_MONITOR=""        # monitor
export ICON_DEV_KEYBOARD=""       # keyboard
export ICON_DEV_MOUSE=""          # mouse
export ICON_DEV_TRACKPAD=""       # cursor
export ICON_DEV_PHONE=""          # device-mobile
export ICON_DEV_WATCH=""          # watch
export ICON_DEV_TABLET=""         # device-tablet
export ICON_DEV_OTHER=""          # bluetooth

# -- Workspaces -- drawn from Phosphor-Fill, so the dot is solid ---------------
export ICON_WS_ACTIVE=""     # circle
