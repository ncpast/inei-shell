-- MINIMIZE 
-- The Quickshell dock lists whatever sit in a special workspace 
-- (`hyprctl clients -j`, workspace.name == "special:minimized") and
-- restores it by calling Minimize.restore(address) on whichever workspace is active.
--
-- hyprctl dispatch 'function() Minimize.active() end'              minimize the focused window
-- hyprctl dispatch 'function() Minimize.window("0x...") end'       minimize that window
-- hyprctl dispatch 'function() Minimize.restore("0x...") end'      bring it to the active workspace + focus

Minimize = { WORKSPACE = "special:minimized" }

local function sel(address)
    address = tostring(address)
    if address:sub(1, 2) ~= "0x" then address = "0x" .. address end
    return "address:" .. address
end

function Minimize.window(address)
    hl.dispatch(hl.dsp.window.move({ workspace = Minimize.WORKSPACE, follow = false, window = sel(address) }))
end

function Minimize.active()
    local w = hl.get_active_window()
    if not w or (w.workspace and w.workspace.name == Minimize.WORKSPACE) then return end
    Minimize.window(w.address)
end

function Minimize.restore(address)
    local ws = hl.get_active_workspace()
    if not ws then return end
    -- a fullscreen window on the target workspace would hide the restored one
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = false, window = sel(address) }))
    hl.dispatch(hl.dsp.focus({ window = sel(address) }))
end
