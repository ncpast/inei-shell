-- ============================================================================
-- HYPRLAND CONFIGURATION (Lua, Hyprland >= 0.55)
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- ============================================================================

-- VARIABLES
-- (colors.lua / autofloat-enabled.lua are required by the modules that use them)

-- MONITORS
-- eDP-1: 2880x1620 @120 Hz, or @60 Hz on the power-saver profile (modules/monitor.lua)
require("modules.monitor").apply()

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
    mirror   = "eDP-1",
})

-- ENVIRONMENT VARIABLES
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("DESKTOP_SESSION", "Hyprland")
hl.env("KDE_FULL_SESSION", "false")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_USE_PORTAL", "0")

-- NVIDIA-specific, needed for correct Wayland rendering on Nvidia GPUs
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

hl.config({
    -- Disables the hardware cursor plane — fixes cursor stutter on some Nvidia setups
    cursor = {
        no_hardware_cursors = true,
    },

    -- Don't switch the panel into HDR / wide-gamut mode when a fullscreen app (e.g. Electron
    -- apps like VSCodium) says its content is HDR: the switch is a full modeset (black flash),
    -- and the panel then runs wide gamut at 8-bit (washed-out picture + a warning).
    render = {
        cm_auto_hdr = 0,
    },

    -- Render XWayland apps at native resolution instead of Hyprland's scaled output
    xwayland = {
        force_zero_scaling = true,
    },

    -- LAYOUTS
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = 1,    -- 0/1 toggles the built-in anime mascot wallpapers
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,

        background_color = 0xff000000,

        allow_session_lock_restore = true, -- a restarted quickshell can take the lock back after a crash

        vrr = 1, -- variable refresh rate / G-Sync, where the monitor supports it
    },
})

-- MODULES
-- Order matters: windowrules last (rules are evaluated top to bottom).
require("modules.plugins")
require("modules.autostart")
require("modules.visual")
require("modules.input")
require("modules.windowrules")
require("modules.focusmode")
require("modules.minimize")
