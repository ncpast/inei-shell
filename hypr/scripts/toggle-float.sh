#!/bin/bash

win=$(hyprctl activewindow -j)
[[ -z "$win" || "$win" == "{}" ]] && exit 0

if [[ "$(echo "$win" | jq -r '.floating')" == "true" ]]; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "unset" })'
else
    w=$(echo "$win" | jq -r '.size[0] - 60')
    h=$(echo "$win" | jq -r '.size[1] - 60')

    hyprctl dispatch 'hl.dsp.window.float({ action = "set" })'
    hyprctl dispatch "hl.dsp.window.resize({ x = $w, y = $h, relative = false })"
    hyprctl dispatch 'hl.dsp.window.move({ x = 0, y = 16, relative = true })'   # 32 / 2: compensate for the title bar
fi