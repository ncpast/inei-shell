local autofloat = require("bool.autofloat-enabled")

-- LAYER RULES - blur / transparency for shell components (bars, launchers, etc.)
hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "waybar" },                     blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "quickshell" },                 blur = true, ignore_alpha = 0.1, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell-notifications" }, blur = true, ignore_alpha = 0.5, no_anim = true }) -- notification cards (alpha 0.68) are blurred, their drop shadow (Theme.shadow_color, alpha < 0.5) isn't
hl.layer_rule({ match = { namespace = "quickshell-search" },        blur = true, ignore_alpha = 0.5, no_anim = false, animation = "fade" }) -- app search card (alpha 0.68) is blurred, its drop shadow isn't; Hyprland fades the whole layer in/out (layersIn / layersOut, fadeLayersIn / fadeLayersOut)
hl.layer_rule({ match = { namespace = "quickshell-lock" },            blur = false, no_anim = true }) -- lockscreen fade overlay: opacity is animated in QML
hl.layer_rule({ match = { namespace = "quickshell-desktop" },        blur = false, order = -1 }) -- desktop icons: no blur; order -1 keeps them above the wallpaper layer (awww)
hl.layer_rule({ match = { namespace = "shell:controlpanel" },         blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "qs_overlay" },                 blur = true, order = -1 }) -- keep overlay beneath other layers
hl.layer_rule({ match = { namespace = "rofi" },                       blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "logout_dialog" },              blur = true })
hl.layer_rule({ match = { namespace = "^hyprbars$" },                 ignore_alpha = 0.5 })

-- WINDOW RULES - GENERAL BEHAVIOR (evaluated top to bottom)

-- Cap floating window size so nothing overflows the visible screen area
hl.window_rule({
    name     = "max-size-floating",
    match    = { float = true },
    max_size = { 1844, 993 },
})

hl.window_rule({
    name  = "all-float",
    match = { class = ".*" },
    float = autofloat.enabled,
})

-- Hides the hyprbars title bar on floating/hovering windows
hl.window_rule({
    name  = "hovering-windows-buttons",
    match = { float = false },
    ["hyprbars:no_bar"] = true,
})

hl.window_rule({
    -- Many apps mishandle native maximize requests - ignore them globally
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- NOTE: matches every class, so this already covers CS2 - it makes the
    -- dedicated cs2 rule below redundant (like to keep it just in case)
    name      = "cs2-tearing",
    match     = { class = ".*" },
    immediate = true,
})

hl.window_rule({
    -- Workaround for XWayland windows misbehaving mid-drag
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

-- WINDOW RULES - APP-SPECIFIC
hl.window_rule({ match = { class = "cs2" }, immediate = true }) -- tearing / immediate rendering for CS2

hl.window_rule({
    name   = "shell-settings",                       -- the Quickshell settings app (SUPER + comma)
    match  = { class = "^org\\.quickshell$", title = "^Shell Settings$" },
    float  = true,
    size   = { 900, 600 },
    center = true,
})

hl.window_rule({
    name   = "shell-calculator",                     -- the Quickshell calculator app (apps/calculator)
    match  = { class = "^org\\.quickshell$", title = "^Calculator$" },
    float  = true,
    size   = { 320, 560 },
    center = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name    = "transparent-windows",
    match   = { class = "^(discord|org.telegram.desktop|spotify)$" },
    opacity = "0.9",
})
