#!/bin/sh
# Run by greetd once per boot (initial_session in /etc/greetd/config.toml), as siro, no password.
# Switch: ~/.config/hypr/bool/autologin-enabled.lua
#   enabled = true   straight into Hyprland, locked by quickshell (LOCK_ON_LOGIN=1, see
#                    modules/autostart.lua and quickshell's Lock/Lock.qml)
#   enabled = false  exit right away: greetd then shows tuigreet (default_session)
# Missing / unreadable switch file counts as off.

switch="$HOME/.config/hypr/bool/autologin-enabled.lua"

if grep -Eq 'enabled[[:space:]]*=[[:space:]]*true' "$switch" 2>/dev/null; then
    # the console stays on screen until Hyprland takes over: blank it and hide its blinking cursor
    printf '\033[2J\033[H\033[?25l' 2>/dev/null
    # silence Hyprland's console output (ASCII logo + log lines); its real log is still written to
    # $XDG_RUNTIME_DIR/hypr/<instance>/hyprland.log
    exec env LOCK_ON_LOGIN=1 /usr/bin/start-hyprland >/dev/null 2>&1
fi
exit 0
