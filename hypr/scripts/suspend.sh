#!/bin/bash
# Sleep (menu bar, lockscreen button).
#
#   suspend.sh            ask quickshell to lock (fades in), fade to black, then it calls
#                         back with --now. Falls back to suspending directly if quickshell
#                         isn't running.
#   suspend.sh --now      the screen is black: actually suspend.
#   suspend.sh --resumed  called by quickshell right after waking up.

case "$1" in
    --now)
        # hyprsunset doesn't survive a suspend; stop it while the screen is black, so the
        # colour change isn't visible
        killall -9 hyprsunset 2>/dev/null
        systemctl suspend
        ;;
    --resumed)
        pgrep -x hyprsunset >/dev/null || setsid -f hyprsunset --temperature 4500 >/dev/null 2>&1
        ;;
    *)
        qs ipc call lock suspend 2>/dev/null || exec "$0" --now
        ;;
esac
