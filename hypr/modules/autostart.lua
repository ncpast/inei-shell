-- ---- Locked from the start (greetd autologin, LOCK_ON_LOGIN=1) -----------------------------------
-- Until quickshell's lock is up nothing may react: the cursor is invisible and every keybind is off
-- (empty "boot" submap). Quickshell (Lock/Lock.qml) ends this once the lock covers the screens:
-- writes the marker file and resets the submap; the cursor comes back on the first mouse movement over
-- the lock screen (or on unlock). The marker ($XDG_RUNTIME_DIR: cleared on logout / reboot) keeps
-- config reloads later in the session from hiding the cursor again.
-- If quickshell never locks, this stays closed: Ctrl+Alt+F2 for a text login.

local login_lock_marker = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-login-lock-done"
local function login_lock_pending()
    if os.getenv("LOCK_ON_LOGIN") ~= "1" then return false end
    local f = io.open(login_lock_marker, "r")
    if f then f:close() return false end
    return true
end

hl.define_submap("boot", function()
    hl.bind("SUPER + F12", hl.dsp.no_op())   -- a submap needs a bind to exist; this one does nothing
end)

if login_lock_pending() then
    hl.config({ cursor = { invisible = true } })
end

-- The cursor still flashes up a couple of times at boot despite cursor.invisible.
-- Parked with its tip in the bottom-right corner (moves are clamped to the screen), the arrow is
-- drawn off screen, so those flashes show at most a pixel. Also after a monitor is (re)added, which
-- can put the cursor back in the middle. It's revealed from there on the first mouse movement.
local function park_login_cursor()
    if login_lock_pending() then hl.dispatch(hl.dsp.cursor.move({ x = 99999, y = 99999 })) end
end
hl.on("monitor.added", park_login_cursor)

hl.on("hyprland.start", function()
    park_login_cursor()
    if login_lock_pending() then hl.dispatch(hl.dsp.submap("boot")) end
    -- greetd autologin (/etc/greetd/config.toml, initial_session) sets LOCK_ON_LOGIN=1 (not set for
    -- logins through tuigreet, which already asked for the password). Then the screen stays black
    -- until the lock is up: quickshell locks while it loads (QS_LOCK_AT_START, Lock/Lock.qml) and the
    -- wallpaper only starts once the lock covers the screens (gives up waiting after 5 s).
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY")

    hl.exec_cmd([[sh -c 'if [ "$LOCK_ON_LOGIN" = 1 ]; then for i in $(seq 100); do [ "$(qs ipc call lock isLocked 2>/dev/null)" = true ] && break; sleep 0.05; done; fi; exec /usr/bin/awww-daemon']]) -- wallpaper daemon
    hl.exec_cmd("hyprpm reload")                 -- reload/apply plugin manager state
    -- shell / bar: use the current GTK icon theme for all Quickshell icons
    hl.exec_cmd([[sh -c '[ "$LOCK_ON_LOGIN" = 1 ] && export QS_LOCK_AT_START=1; QS_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "\047") exec quickshell']])
    hl.exec_cmd([[udiskie --notify --automount --tray --file-manager nautilus --terminal "kitty --directory"]])
    hl.exec_cmd("hyprctl setcursor breeze_cursors 24")
    hl.exec_cmd("kwalletd6 --kwallet6")          -- KDE wallet daemon
    hl.exec_cmd("hyprsunset --temperature 4500") -- night-light style warm color temp

    hl.exec_cmd("wl-paste --type text --watch cliphist store -max-items 10 store")
end)
