-- luacheck: globals AddSimSpeedChange RemoveSimSpeedChange AddInputBlock RemoveInputBlock CurrentRun
-- luacheck: globals ActiveScreens SessionMapState MapState IsEmpty AdamantQuickPause_Anchor

local logic = {}

logic.SIM_SPEED_NAME = "AdamantQuickPause"
logic.INPUT_BLOCK_NAME = "AdamantQuickPause"
-- The engine slows simulation speed by a fraction; a true zero is avoided in case it is rejected.
logic.MIN_FRACTION = 0.001
logic.LERP_TIME = 0.0001

local state = {
    paused = false,
    inputBlocked = false,
    lastSignature = nil,
}

function logic.isPaused()
    return state.paused
end

--- 0% means "frozen" and maps to the smallest usable fraction.
function logic.fractionForPercent(percent)
    local fraction = (tonumber(percent) or 0) / 100
    if fraction < logic.MIN_FRACTION then
        return logic.MIN_FRACTION
    end
    return fraction
end

--- Only toggle during plain gameplay: a run is active, the player is alive, and no screen
--- (boon choice, codex, trait tray, ...) is open.
function logic.canToggle(context)
    return context.hasRun == true
        and context.handlingDeath ~= true
        and context.openScreenCount == 0
end

function logic.readGameContext()
    local screens = ActiveScreens
    return {
        hasRun = CurrentRun ~= nil,
        handlingDeath = SessionMapState ~= nil and SessionMapState.HandlingDeath == true,
        openScreenCount = (screens == nil or IsEmpty(screens)) and 0 or 1,
    }
end

local function applySimSpeed(settings)
    AddSimSpeedChange(logic.SIM_SPEED_NAME, {
        Fraction = logic.fractionForPercent(settings.speedPercent),
        LerpTime = logic.LERP_TIME,
        Priority = true,
    })
end

function logic.pause(settings)
    if state.paused then
        return
    end
    applySimSpeed(settings)
    if settings.blockInput then
        AddInputBlock({ Name = logic.INPUT_BLOCK_NAME })
        state.inputBlocked = true
    end
    state.paused = true
    state.lastSignature = nil
end

function logic.resume()
    if not state.paused then
        return
    end
    RemoveSimSpeedChange(logic.SIM_SPEED_NAME, { LerpTime = logic.LERP_TIME })
    if state.inputBlocked then
        RemoveInputBlock({ Name = logic.INPUT_BLOCK_NAME })
        state.inputBlocked = false
    end
    state.paused = false
end

function logic.toggle(settings)
    if state.paused then
        logic.resume()
    else
        logic.pause(settings)
    end
    return state.paused
end

--- The game keeps its simulation-speed requests in MapState.SimSpeedChanges. If ours disappears while
--- paused (a map-state reset, ClearSimSpeedChanges), put it back so the freeze lasts until toggled off.
--- Returns true when the freeze had to be re-applied.
function logic.ensureApplied(settings)
    if not state.paused then
        return false
    end
    local changes = MapState ~= nil and MapState.SimSpeedChanges or nil
    if changes == nil or changes[logic.SIM_SPEED_NAME] ~= nil then
        return false
    end
    applySimSpeed(settings)
    return true
end

--- "name=fraction" list of every active simulation-speed request, for diagnostics.
function logic.simSpeedSignature()
    local changes = MapState ~= nil and MapState.SimSpeedChanges or nil
    if changes == nil then
        return "(no map state)"
    end
    local parts = {}
    for name, change in pairs(changes) do
        parts[#parts + 1] = string.format("%s=%s", tostring(name), tostring(change.Fraction))
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "(none)"
end

--- True once per change of the signature while paused, so a debug log shows who else touched speed.
function logic.signatureChanged()
    if not state.paused then
        return false, nil
    end
    local signature = logic.simSpeedSignature()
    if signature == state.lastSignature then
        return false, signature
    end
    state.lastSignature = signature
    return true, signature
end

function logic.readSettings(runtime)
    return {
        speedPercent = runtime.data.read("SpeedPercent"),
        blockInput = runtime.data.read("BlockInput"),
    }
end

-- Hot-reload-stable anchor: the always-draw callback is registered once per game session and calls
-- whatever tick is installed, so a reload replaces behavior without registering a second callback.
local function resolveKey(name)
    local keys = rom.ImGuiKey
    if type(keys) ~= "table" or name == nil or name == "" then
        return nil
    end
    return keys[name] or keys["ImGuiKey_" .. name]
end

local function installTick(tick)
    AdamantQuickPause_Anchor = AdamantQuickPause_Anchor or {}
    local anchor = AdamantQuickPause_Anchor
    anchor.tick = tick
    anchor.failed = false
    if not anchor.registered then
        anchor.registered = true
        rom.gui.add_always_draw_imgui(function()
            local current = anchor.tick
            if current == nil or anchor.failed then
                return
            end
            local ok, err = pcall(current)
            if not ok then
                -- Report once instead of every frame; a reload installs a fresh tick and clears this.
                anchor.failed = true
                print("[Quick_Pause] hotkey tick disabled: " .. tostring(err))
            end
        end)
    end
end

function logic.attach(module)
    local live = { host = nil, runtime = nil }

    module.onActivate(function(host, runtime)
        live.host = host
        live.runtime = runtime
    end)

    -- Disabling the module, or leaving the run, must never leave the game frozen.
    module.onCommit(function(host)
        if not host.isEnabled() then
            logic.resume()
        end
    end)
    module.hooks.wrap("StartNewRun", function(_, _, baseFunc, ...)
        logic.resume()
        return baseFunc(...)
    end)
    module.hooks.wrap("StartRoom", function(_, _, baseFunc, ...)
        logic.resume()
        return baseFunc(...)
    end)

    installTick(function()
        local host, runtime = live.host, live.runtime
        if host == nil or runtime == nil or not host.isEnabled() then
            return
        end

        if logic.isPaused() then
            if logic.ensureApplied(logic.readSettings(runtime)) then
                host.logIf("freeze was removed from MapState.SimSpeedChanges; re-applied")
            end
            local changed, signature = logic.signatureChanged()
            if changed then
                host.logIf("sim speed requests while paused: %s", signature)
            end
        end

        if rom.gui.is_open() == true then
            return
        end
        local hotkey = resolveKey(runtime.data.read("Hotkey"))
        if hotkey == nil or rom.ImGui.IsKeyPressed(hotkey, false) ~= true then
            return
        end
        if logic.isPaused() or logic.canToggle(logic.readGameContext()) then
            local nowPaused = logic.toggle(logic.readSettings(runtime))
            host.logIf("hotkey toggled pause -> %s (%s)", tostring(nowPaused), logic.simSpeedSignature())
        end
    end)

    local overlays = module.overlays
    overlays.createLine("state", {
        componentName = "QuickPause_Indicator",
        region = "centerLowerStack",
        order = overlays.order.module + 10,
        visible = function(host, runtime)
            return host.isEnabled() and runtime.data.read("ShowIndicator") == true and logic.isPaused()
        end,
        columns = {
            {
                key = "text",
                minWidth = 200,
                justify = "Center",
                textArgs = {
                    Color = { 1.0, 0.82, 0.2, 1.0 },
                    FontSize = 22,
                },
            },
        },
    })
    overlays.onInterval("state", 0.1, function(_, _, overlay)
        overlay.setLine("state", { text = "PAUSED" })
        overlay.refresh("state")
    end)
end

return logic
