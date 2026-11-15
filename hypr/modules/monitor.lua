-- Built-in display: 120 Hz normally, 60 Hz while the power profile is power-saver.
-- Applied when the config loads (hyprland.lua), and again by quickshell (Utils/RefreshRate.qml) every
-- time the profile changes, through
--   hyprctl dispatch 'function() require("modules.monitor").apply() end'
local M = {}

local function power_saver()
    -- timeout: this runs while the config loads, and power-profiles-daemon may not be up yet at login
    local p = io.popen("timeout 1 powerprofilesctl get 2>/dev/null")
    if not p then return false end
    local profile = p:read("*l")
    p:close()
    return profile == "power-saver"
end

function M.apply()
    hl.monitor({
        output   = "eDP-1",
        mode     = power_saver() and "2880x1620@60" or "2880x1620@120",
        position = "0x0",
        scale    = 1.5,
    })
end

return M
