-- Remember every bind's dispatcher by its description, in the global table `Binds`, so other
-- programs (the Quickshell menu bar) can run exactly what a shortcut does without
-- duplicating it:   hyprctl dispatch 'Binds["toggle-float"]'
-- Binds are looked up by `description`, so keep those names stable.
Binds = {}
local original_bind = hl.bind
hl.bind = function(keys, dispatcher, opts)
    if opts and opts.description then Binds[opts.description] = dispatcher end
    return original_bind(keys, dispatcher, opts)
end

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "nautilus"
-- local menu        = "~/.config/rofi/launchers/type-1/launcher.sh" -- swap for "rofi -show drun" to use plain rofi
local menu        = "qs ipc call search toggle"

hl.config({
    input = {
        kb_layout  = "us, ua",
        kb_options = "grp:alt_shift_toggle", -- Alt+Shift toggles keyboard layout

        follow_mouse = 2,
        sensitivity  = 0,
        float_switch_override_focus = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- 3-finger swipe switches workspaces
hl.gesture({
    fingers   = 3,
    direction = "vertical",
    action    = "workspace",
})

-- Every bind has a `description`: the Quickshell shortcut viewer looks binds up
-- by it (via `hyprctl binds -j`), so keep these names stable.

-- KEYBINDINGS - CORE APPS & ACTIONS
-- focus-mode aware: black & white kitty on a focus-mode workspace (modules/focusmode.lua)
hl.bind(mainMod .. " + Q",      function() FocusMode.terminal() end,                   { description = "terminal" })
hl.bind(mainMod .. " + C",      hl.dsp.window.close(),                                 { description = "close-window" })
hl.bind(mainMod .. " + D",      function() Minimize.active() end,                                 { description = "minimize-window" })
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager),                          { description = "file-manager" })
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(menu),                                 { description = "launcher" })
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("qs ipc call lock lock"),             { description = "lock-screen" })
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd("qs ipc call settings toggle"),      { description = "shell-settings" })
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), { description = "exit-hyprland" })
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo(),                                { description = "toggle-pseudo" }) -- dwindle: pseudo-tiling
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("/home/siro/.config/hypr/scripts/toggle-float.sh"), { description = "toggle-float" })
--hl.bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }),            { description = "toggle-float" })

-- KEYBINDINGS - CLIPBOARD, SCREENSHOTS & COLOR PICKER
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd([[bash -c "wl-copy $(cliphist list | rofi -dmenu -p 'Search Clipboard' | cliphist decode)"]]), { description = "clipboard-history" })

hl.bind("Print",         hl.dsp.exec_cmd("hyprshot -m region -m eDP-1 -o /tmp/screenshots"),                       { description = "screenshot" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename -"),     { description = "screenshot-edit" })

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "color-picker" })

-- Optional pinch-zoom binds - require the external `hypr-zoom` script
-- hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.exec_cmd("hypr-zoom -easing=InOutCubic -interp=Linear -target=2.0"), { description = "zoom-in" })
-- hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.exec_cmd("hypr-zoom -easing=InOutCubic -interp=Linear -target=1.0"), { description = "zoom-out" })

-- KEYBINDINGS - FOCUS, WINDOW & WORKSPACE MOVEMENT
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "focus-left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "focus-right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "focus-up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "focus-down" })

hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }),    { description = "move-window-up" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }),  { description = "move-window-down" })
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }),  { description = "move-window-left" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "move-window-right" })

hl.bind(mainMod .. " + W",          hl.dsp.focus({ workspace = "-1" }), { description = "workspace-prev" })
hl.bind(mainMod .. " + S",          hl.dsp.focus({ workspace = "+1" }), { description = "workspace-next" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "workspace-scroll-prev" })
hl.bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }), { description = "workspace-scroll-next" })

-- Workspaces 1-10 (key 0 = workspace 10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       { description = "workspace-" .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "move-to-workspace-" .. i })
end

hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ workspace = "r+1" }), { description = "move-to-next-workspace" })

-- Send window to scratchpad
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "send-to-scratchpad" })

-- Move/resize windows with LMB/RMB
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "drag-window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "resize-window" })

-- KEYBINDINGS - MEDIA & BRIGHTNESS KEYS
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "volume-up" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "volume-down" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "mute" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "mic-mute" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "brightness-up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true, description = "brightness-down" })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "media-next" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "media-pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "media-play" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "media-prev" })