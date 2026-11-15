-- FOCUS MODE — "no distractions" look, toggled live by Quickshell:
--   menu bar → View → Focus Mode             global: every workspace
--   menu bar → Workspace → Focused Workspace  local: only the current workspace
-- For a workspace in focus mode:
--   * no gaps (gaps_in / gaps_out = 0) and no rounded corners
--   * solid white border on the active window, dark grey on the others (no gradient)
--
-- Quickshell calls these through hyprctl, e.g.
--   hyprctl dispatch 'function() FocusMode.set(3, true) end'
--   hyprctl dispatch 'function() FocusMode.setGlobal(true) end'
--   hyprctl dispatch 'function() FocusMode.clear() end'
-- Rules are created once per workspace selector (disabled) and then only switched on/off, so a
-- toggle takes effect immediately without reloading the config. State is session-only:
-- a config reload starts from scratch and Quickshell re-applies its own state.

FocusMode = { rules = {} }

-- every regular workspace (special workspaces have negative ids and are left alone)
local GLOBAL_SELECTOR = "r[1-1000]"

-- key is a workspace selector: a workspace id ("3") or a range (GLOBAL_SELECTOR)
local function rulesFor(key)
    if not FocusMode.rules[key] then
        FocusMode.rules[key] = {
            hl.workspace_rule({
                workspace   = key,
                gaps_in     = 0,
                gaps_out    = 0,
                no_rounding = true,
                enabled     = false,
            }),
            hl.window_rule({
                name         = "focus-mode-" .. (key == GLOBAL_SELECTOR and "global" or key),
                match        = { workspace = key },
                border_color = "rgb(8a8a8a) rgb(333333)", -- active, inactive
                border_size  = 0,
                enabled      = false,
            }),
        }
    end
    return FocusMode.rules[key]
end

local function setRules(key, on)
    for _, rule in ipairs(rulesFor(key)) do
        rule:set_enabled(on)
    end
end

function FocusMode.set(ws, on) setRules(tostring(ws), on) end
function FocusMode.setGlobal(on) setRules(GLOBAL_SELECTOR, on) end

-- Is workspace ws (default: the active one) in focus mode, globally or on its own?
function FocusMode.isActive(ws)
    if ws == nil then
        local active = hl.get_active_workspace()
        ws = active and active.id
    end
    local function on(key)
        local rules = FocusMode.rules[key]
        return rules ~= nil and rules[1]:is_enabled()
    end
    return on(GLOBAL_SELECTOR) or (ws ~= nil and on(tostring(ws)))
end

-- Terminal that matches the workspace: the black & white focus config on a focus-mode
-- workspace, the normal (matugen) one elsewhere. Bound to SUPER+Q in input.lua.
function FocusMode.terminal()
    if FocusMode.isActive() then
        hl.exec_cmd("kitty --config ~/.config/kitty/focus.conf")
    else
        hl.exec_cmd("kitty")
    end
end

function FocusMode.clear()
    for _, rules in pairs(FocusMode.rules) do
        for _, rule in ipairs(rules) do
            rule:set_enabled(false)
        end
    end
end
