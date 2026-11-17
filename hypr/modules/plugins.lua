local colors = require("modules.colors")

-- Plugins are built by scripts/build-plugins.sh into ~/.local/share/hypr-plugins
-- and loaded directly here (hyprpm is not used). Rebuild after every Hyprland
-- update, otherwise the plugins pause/fail on the version mismatch.
local plugin_dir = os.getenv("HOME") .. "/.local/share/hypr-plugins/"
for _, name in ipairs({ "hyprbars", "dynamic-cursors" }) do
    local ok, err = pcall(hl.plugin.load, plugin_dir .. name .. ".so")
    if not ok then print("plugin " .. name .. " failed to load: " .. tostring(err)) end
end

-- Settings are applied from config.reloaded, once the plugins are loaded.

local function setup_plugins()
    hl.config({
        plugin = {
            hyprbars = {
                bar_height         = 32,
                bar_color          = colors.background,
                bar_padding        = 10,
                bar_button_padding = 10,

                bar_text_font         = "Inter",
                bar_text_size         = 13,
                bar_text_align        = "center",
                bar_buttons_alignment = "left",
                bar_text_weight       = "bold",
                col = { text = colors.text },

                icon_on_hover = true,

                on_double_click = [[hyprctl dispatch 'hl.dsp.window.pin()']],
                bar_precedence_over_border = false,
                bar_part_of_window = true,
                enabled = true,
            },

            dynamic_cursors = {
                enabled   = true,
                mode      = "tilt", -- tilt | rotate | stretch | none

                -- minimum angle change (degrees) before the cursor shape updates
                threshold = 2,

                -- used when mode = rotate
                rotate = {
                    length = 20,  -- simulated stick length in px, match your actual cursor size
                    offset = 0.0, -- clockwise angle offset applied to all shapes
                },

                -- used when mode = tilt
                tilt = {
                    limit      = 5000,                -- px/s speed for full tilt
                    activation = "negative_quadratic", -- linear | quadratic | negative_quadratic
                    window     = 100,                 -- ms window for speed averaging
                    full       = 30,                  -- max tilt angle per side, in degrees
                },

                -- used when mode = stretch
                stretch = {
                    limit      = 3000, -- px/s speed for full stretch (2x length)
                    activation = "quadratic",
                    window     = 100,
                },

                -- shake-to-find-cursor
                shake = {
                    enabled   = true,
                    threshold = 6.0,  -- lower = detected sooner
                    base      = 4.0,  -- magnification right after shake starts
                    speed     = 4.0,  -- magnification increase per second while shaking
                    influence = 0.0,
                    limit     = 0.0,  -- 0 = uncapped magnification
                    timeout   = 2000, -- ms to stay magnified after shaking stops
                    effects   = false, -- apply tilt/rotate/stretch while shaking
                    ipc       = false,
                },

                -- higher-res cursor texture while magnified
                hyprcursor = {
                    nearest    = true,        -- pixelated scaling when no highres image is available
                    enabled    = true,
                    resolution = -1,          -- -1 = derive from cursor size * shake:base
                    fallback   = "clientside", -- shape used for clientside cursors when magnified
                },
            },
        },
    })

    hl.plugin.hyprbars.add_button({
        fg_color = "rgb(ff5f59)",
        bg_color = "rgb(ff5f59)",
        size     = 16,
        icon     = "",
        action   = [[hyprctl dispatch 'hl.dsp.window.close()']],
    })
    
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(febb31)",
        fg_color = "rgb(febb31)",
        size     = 16,
        icon     = "",
        action   = [[hyprctl dispatch 'function() Minimize.active() end']],
    })
    
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(2cc842)",
        fg_color = "rgb(2cc842)",
        size     = 16,
        icon     = "",
        action   = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']],
    })

end

hl.on("config.reloaded", setup_plugins)

-- Pinned windows get a pin glyph (Nerd Font) in front of their hyprbars title; unpinning restores the
-- live title. pcall: tiled windows have no bar to retitle.
local PIN_PREFIX = "  "
local function mark_pinned(w)
    if not w or not hl.plugin.hyprbars then return end
    pcall(hl.plugin.hyprbars.set_title, w, w.pinned and (PIN_PREFIX .. w.title) or nil)
end
hl.on("window.pin", mark_pinned)
hl.on("window.title", function(w)
    if w and w.pinned then mark_pinned(w) end
end)

--[[ HYPRGLASS (liquid glass) — https://github.com/hyprnux/hyprglass
-- Same load-order caveat as above: hl.plugin.hyprglass only exists once the
-- plugin is loaded, so the block is guarded and re-applied on every reload.
-- Glass only shows on windows that are translucent (opacity < 1).

local function setup_hyprglass()
    local hg = hl.plugin.hyprglass
    if not hg then return end

    hg.config({
        enabled             = false,
        default_theme       = "dark",   -- dark | light
        default_preset      = "default", -- built-ins: clear, subtle, glass, high_contrast, pomme

        manage_window_blur  = true,  -- plugin sets no_blur on glassed windows itself
        skip_opaque_windows = true,  -- don't render glass hidden behind opaque windows

        blur_strength        = 2.0,
        blur_iterations      = 3,
        refraction_strength  = 0.6,
        chromatic_aberration = 0.5,
        lens_distortion      = 0.5,
        specular_strength    = 0.8,
        glass_opacity        = 1.0,
        tint_color           = 0x8899aa22, -- RRGGBBAA, alpha = tint strength

        -- glass on layer surfaces (waybar, notifications, launchers) — off by default
        layers = { enabled = false },
    })
end

hl.on("config.reloaded", setup_hyprglass)
]]
