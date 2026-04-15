#!/usr/bin/env bash

position=$(slurp)
swaymsg seat - hide_cursor 1 >/dev/null
sleep 0.1
grim -g "$position" -
swaymsg seat - hide_cursor 0 >/dev/null
