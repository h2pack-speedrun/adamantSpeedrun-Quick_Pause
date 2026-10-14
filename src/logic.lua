-- luacheck: globals AddSimSpeedChange RemoveSimSpeedChange AddInputBlock RemoveInputBlock CurrentRun
-- luacheck: globals ActiveScreens SessionMapState MapState IsEmpty AdamantQuickPause_Anchor
-- luacheck: globals UpdateSimulationSpeed GetTime _worldTime

local logic = {}

logic.SIM_SPEED_NAME = "AdamantQuickPause"
logic.INPUT_BLOCK_NAME = "AdamantQuickPause"
-- The engine slows simulation speed by a fraction; a true zero is avoided in case it is rejected.
logic.MIN_FRACTION = 0.001
logic.LERP_TIME = 0.0001
-- The engine has been seen returning to normal speed a couple of seconds into a freeze while the game's
-- own request list still holds ours, so the current speed is re-sent to the engine at this interval.
logic.REASSERT_SECONDS = 0.25
-- The PAUSED badge is drawn with ImGui, not the game HUD: HUD fades run on game time, so at a speed of
-- 0.001 a game-drawn label would take minutes to appear.
logic.INDICATOR_X = 24
logic.INDICATOR_Y = 24
logic.INDICATOR_TEXT = "PAUSED"
logic.PROBE_SECONDS = 1.0

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

--- Re-send the lowest active speed request to the engine (UpdateSimulationSpeed forwards it to
--- AdjustSimulationSpeed). Returns true when a request was sent.
function logic.reassert()
    if not state.paused or UpdateSimulationSpeed == nil then
        return false
    end
    UpdateSimulationSpeed(logic.SIM_SPEED_NAME, { LerpTime = logic.LERP_TIME })
    return true
end

--- Game clocks for measuring real speed: _worldTime follows the simulation, GetTime({}) is system time.
function logic.sampleClocks()
    local ok, systemTime = pcall(GetTime, {})
    return {
        world = type(_worldTime) == "number" and _worldTime or nil,
        system = ok and type(systemTime) == "number" and systemTime or nil,
    }
end

--- Speed ratios between two samples; nil when a clock is missing or no time passed.
function logic.measureSpeed(previous, current)
    if previous == nil or current == nil then
        return nil
    end
    local function ratio(a, b)
        return a ~= nil and b ~= nil and a > 0 and b / a or nil
    end
    local system = previous.system ~= nil and current.system ~= nil and current.system - previous.system or nil
    local world = previous.world ~= nil and current.world ~= nil and current.world - previous.world or nil
    return {
        systemSeconds = system,
        worldSeconds = world,
        worldPerSystem = ratio(system, world),
    }
end

--- Window flags for a small non-interactive badge. Flags are distinct bits, so adding them is a bitwise OR.
function logic.indicatorWindowFlags(flagTable)
    flagTable = flagTable or {}
    return (flagTable.NoTitleBar or 1)
        + (flagTable.NoResize or 2)
        + (flagTable.NoMove or 4)
        + (flagTable.NoScrollbar or 8)
        + (flagTable.AlwaysAutoResize or 64)
        + (flagTable.NoSavedSettings or 256)
        + (flagTable.NoInputs or (512 + 65536 + 131072))
        + (flagTable.NoFocusOnAppearing or 4096)
end

--- Draw the PAUSED badge. Begin/End are always paired; the extras are best effort.
function logic.drawIndicator(imgui, windowFlagTable)
    imgui.SetNextWindowPos(logic.INDICATOR_X, logic.INDICATOR_Y)
    if imgui.SetNextWindowBgAlpha ~= nil then
        imgui.SetNextWindowBgAlpha(0.55)
    end
    local shouldDraw = imgui.Begin("Quick Pause##indicator", logic.indicatorWindowFlags(windowFlagTable))
    if shouldDraw then
        if imgui.SetWindowFontScale ~= nil then
            imgui.SetWindowFontScale(1.8)
        end
        imgui.TextColored(1.0, 0.82, 0.2, 1.0, logic.INDICATOR_TEXT)
    end
    imgui.End()
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

    local timing = { lastReassert = 0, lastProbe = 0, sample = nil }

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

            local now = os.clock()
            if now - timing.lastReassert >= logic.REASSERT_SECONDS then
                timing.lastReassert = now
                logic.reassert()
            end
            if now - timing.lastProbe >= logic.PROBE_SECONDS then
                timing.lastProbe = now
                local current = logic.sampleClocks()
                local speed = logic.measureSpeed(timing.sample, current)
                timing.sample = current
                if speed ~= nil and speed.worldPerSystem ~= nil then
                    host.logIf("measured speed while paused: world %.3fs over system %.3fs = x%.3f",
                        speed.worldSeconds, speed.systemSeconds, speed.worldPerSystem)
                end
            end

            if runtime.data.read("ShowIndicator") == true then
                logic.drawIndicator(rom.ImGui, rom.ImGuiWindowFlags)
            end
        else
            timing.sample = nil
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
end

return logic
