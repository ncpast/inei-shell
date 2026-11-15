-- hyprland.lua — translated from hyprland.conf (10.07.26)
-- Requires Hyprland >= 0.55
-- Wiki: https://wiki.hypr.land/Configuring/Start/

------------------
---- VARIABLES ----
------------------

local accentColor = "rgba(c46042ee)"

local terminal    = "kitty"
local fileManager = "thunar"
-- local menu     = "rofi -show drun"
local menu        = "~/.config/rofi/launchers/type-1/launcher.sh"
local mainMod     = "SUPER"

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "eDP-1",
    mode     = "2880x1620@120",
    position = "0x0",
    scale    = 1.5,
})

-- Any other monitor: mirror the laptop panel
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
    mirror   = "eDP-1",
})

-----------------------
---- LAYER RULES ----
-----------------------

hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "waybar" },                     blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "quickshell" },                 blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "shell:controlpanel" },         blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "qs_overlay" },                 blur = true, order = -1 })
hl.layer_rule({ match = { namespace = "rofi" },                       blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "logout_dialog" },              blur = true })

-- Cap floating window size (note: every window floats, see "all-float" below)
-- hl.window_rule({ match = { class = ".*" }, opacity = "0.1 0.8" }) -- old kitty opacity rule, was commented out
hl.window_rule({
    name     = "max-size-floating",
    match    = { float = true },
    max_size = { 1844, 993 },
})

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY")

    hl.exec_cmd("/usr/bin/awww-daemon")
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("swaync")
    hl.exec_cmd("quickshell")

    hl.exec_cmd("hyprctl setcursor breeze_cursors 24")

    hl.exec_cmd("kwalletd6 --kwallet6")

    hl.exec_cmd("hyprsunset --temperature 4500")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store -max-items 10 store")
    -- hl.exec_cmd("wl-paste --type image --watch cliphist store -max-items 10 store")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("DESKTOP_SESSION", "Hyprland")
hl.env("KDE_FULL_SESSION", "false")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_USE_PORTAL", "0")

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Idk what this does but I hope it fixes stuttering
hl.config({ cursor = { no_hardware_cursors = true } })

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(c46042ee)", "rgba(ed7a1cee)" }, angle = 45 },
            inactive_border = "rgba(595959ee)",
        },

        resize_on_border = true,

        allow_tearing = true,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 15,
        rounding_power = 3,

        active_opacity = 1.0,
        -- inactive_opacity = 0.9,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a, -- ARGB
        },

        blur = {
            -- popups = true,
            enabled           = true,
            size              = 1,
            passes            = 6,
            ignore_opacity    = true,

            noise             = 0.02,
            contrast          = 1.5,

            vibrancy          = 0.1696,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Animations
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
-- hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
-- hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 0.9,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 0.9,  bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 4.94, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 4.21, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 4.94, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "zoomFactor",    enabled = false, speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        -- pseudotile = true,
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 1,
        disable_hyprland_logo   = false,

        -- vfr = true,
        vrr = 1,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us, ua",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("/home/siro/.config/hypr/scripts/wlogout.sh"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Clipboard history picker
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd([[bash -c "wl-copy $(cliphist list | rofi -dmenu -p 'Search Clipboard' | cliphist decode)"]]))

-- Cycle workspaces
hl.bind(mainMod .. " + W", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + S", hl.dsp.focus({ workspace = "e+1" }))

-- Screenshots
hl.bind("Print",         hl.dsp.exec_cmd("hyprshot -m region -m eDP-1"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename -"))

-- Color picker
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Move focus with arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces / move window to workspace with [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

-- Move/resize windows with LMB/RMB
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume / brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media (playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Rules are evaluated top to bottom: order matters.

--hl.window_rule({
--    name  = "hovering-windows-buttons",
--    match = { float = false },
--    ["hyprbars:no_bar"] = true,
--})

hl.window_rule({
    name  = "all-float",
    match = { class = ".*" },
    float = false,
    -- size = { 890, 540 },
})

hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    match     = { class = "cs2" },
    immediate = true,
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name    = "discord-transparent",
    match   = { class = "^(discord|org.telegram.desktop)$" },
    opacity = "0.9",
})

hl.window_rule({
    name      = "cs2-tearing",
    -- match  = { class = "^(cs2)$" },
    match     = { class = ".*" },
    immediate = true,
})

-----------------
---- PLUGINS ----
-----------------
-- Plugins are loaded by `hyprpm reload` AFTER the config is first evaluated,
-- so hl.plugin.* doesn't exist yet on first load. Config is applied from
-- config.reloaded; run `hyprctl reload` once after login.

local function setup_plugins()
    hl.config({
        plugin = {
            hyprbars = {
                bar_height         = 32,
                bar_color          = "rgb(312421)",
                bar_padding        = 10,
                bar_button_padding = 10,

                bar_text_font      = "Inter",
                bar_text_size      = 13,
                bar_text_align     = "center",
                bar_buttons_alignment = "left",

                col = { text = "rgb(ebdbb2)" },

                on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
                bar_precedence_over_border = false,
                bar_part_of_window = true,
                enabled = true,
            },

            overview = {
                hideTopLayers         = false,
                hideRealLayers        = false,
                hideOverlayLayers     = false,
                reservedArea          = 33,
                autoDrag              = false,
                workspaceActiveBorder = accentColor,
                workspaceBorderSize   = 2,
                disableBlur           = false,
                affectStrut           = false,
                -- panelColor = "",
                -- onBottom   = true,
            },

            dynamic_cursors = {
                enabled   = true,
                mode      = "tilt", -- tilt | rotate | stretch | none
                threshold = 2,

                rotate = {
                    length = 20,
                    offset = 0.0,
                },

                tilt = {
                    limit      = 5000,
                    activation = "negative_quadratic",
                    window     = 100,
                    full       = 30,
                },

                stretch = {
                    limit      = 3000,
                    activation = "quadratic",
                    window     = 100,
                },

                shake = {
                    enabled   = true,
                    threshold = 6.0,
                    base      = 4.0,
                    speed     = 4.0,
                    influence = 0.0,
                    limit     = 0.0,
                    timeout   = 2000,
                    effects   = false,
                    ipc       = false,
                },

                hyprcursor = {
                    nearest    = true,
                    enabled    = true,
                    resolution = -1,
                    fallback   = "clientside",
                },
            },
        },
    })

    if hl.plugin and hl.plugin.hyprbars then
        hl.plugin.hyprbars.add_button({
            bg_color = "rgb(ff5f59)",
            size     = 16,
            icon     = "",
            action   = [[hyprctl dispatch 'hl.dsp.window.close()']],
        })
        hl.plugin.hyprbars.add_button({
            bg_color = "rgb(febb31)",
            size     = 16,
            icon     = "",
            action   = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
        })
        hl.plugin.hyprbars.add_button({
            bg_color = "rgb(2cc842)",
            size     = 16,
            icon     = "",
            action   = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']],
        })
    end
end

hl.on("config.reloaded", setup_plugins)