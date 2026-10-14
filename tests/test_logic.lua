local lu = require("luaunit")

local logic = dofile("src/logic.lua")
local data = dofile("src/data.lua")

local calls

local function installGameStubs()
    calls = { sim = {}, removed = {}, inputBlocked = {}, inputUnblocked = {} }
    _G.AddSimSpeedChange = function(name, args)
        calls.sim[#calls.sim + 1] = { name = name, args = args }
    end
    _G.RemoveSimSpeedChange = function(name, args)
        calls.removed[#calls.removed + 1] = { name = name, args = args }
    end
    _G.AddInputBlock = function(args)
        calls.inputBlocked[#calls.inputBlocked + 1] = args.Name
    end
    _G.RemoveInputBlock = function(args)
        calls.inputUnblocked[#calls.inputUnblocked + 1] = args.Name
    end
end

local function clearGameStubs()
    _G.AddSimSpeedChange, _G.RemoveSimSpeedChange = nil, nil
    _G.AddInputBlock, _G.RemoveInputBlock = nil, nil
    _G.MapState = nil
end

local function gameplayContext(overrides)
    local context = {
        hasRun = true,
        handlingDeath = false,
        openScreenCount = 0,
    }
    for key, value in pairs(overrides or {}) do
        context[key] = value
    end
    return context
end

TestFractionForPercent = {}

function TestFractionForPercent:testZeroPercentFreezesWithTheSmallestUsableFraction()
    lu.assertEquals(logic.fractionForPercent(0), logic.MIN_FRACTION)
end

function TestFractionForPercent:testPercentMapsToFraction()
    lu.assertAlmostEquals(logic.fractionForPercent(25), 0.25, 1e-9)
    lu.assertAlmostEquals(logic.fractionForPercent(90), 0.9, 1e-9)
end

function TestFractionForPercent:testMissingValueFreezes()
    lu.assertEquals(logic.fractionForPercent(nil), logic.MIN_FRACTION)
end

TestCanToggle = {}

function TestCanToggle:testAllowedDuringPlainGameplay()
    lu.assertTrue(logic.canToggle(gameplayContext()))
end

function TestCanToggle:testOpenScreensDeathAndNoRunBlockStartingAFreeze()
    lu.assertFalse(logic.canToggle(gameplayContext({ openScreenCount = 1 })))
    lu.assertFalse(logic.canToggle(gameplayContext({ handlingDeath = true })))
    lu.assertFalse(logic.canToggle(gameplayContext({ hasRun = false })))
end

TestPauseState = {}

function TestPauseState:setUp()
    installGameStubs()
    logic.resume()
    calls.sim, calls.removed = {}, {}
end

function TestPauseState:tearDown()
    logic.resume()
    clearGameStubs()
end

function TestPauseState:testPauseAppliesOneSimSpeedChangeAndResumeRemovesIt()
    logic.pause({ speedPercent = 0, blockInput = false })

    lu.assertTrue(logic.isPaused())
    lu.assertEquals(#calls.sim, 1)
    lu.assertEquals(calls.sim[1].name, logic.SIM_SPEED_NAME)
    lu.assertEquals(calls.sim[1].args.Fraction, logic.MIN_FRACTION)
    lu.assertTrue(calls.sim[1].args.Priority)

    logic.resume()
    lu.assertFalse(logic.isPaused())
    lu.assertEquals(#calls.removed, 1)
    lu.assertEquals(calls.removed[1].name, logic.SIM_SPEED_NAME)
end

function TestPauseState:testPauseAndResumeAreIdempotent()
    logic.pause({ speedPercent = 0 })
    logic.pause({ speedPercent = 0 })
    lu.assertEquals(#calls.sim, 1)

    logic.resume()
    logic.resume()
    lu.assertEquals(#calls.removed, 1)
end

function TestPauseState:testToggleAlternates()
    logic.toggle({ speedPercent = 0 })
    lu.assertTrue(logic.isPaused())
    logic.toggle({ speedPercent = 0 })
    lu.assertFalse(logic.isPaused())
end

function TestPauseState:testBlockInputIsAppliedAndReleasedWithThePause()
    logic.pause({ speedPercent = 0, blockInput = true })
    lu.assertEquals(calls.inputBlocked, { logic.INPUT_BLOCK_NAME })

    logic.resume()
    lu.assertEquals(calls.inputUnblocked, { logic.INPUT_BLOCK_NAME })
end

function TestPauseState:testNoInputBlockWhenTheOptionIsOff()
    logic.pause({ speedPercent = 0, blockInput = false })
    logic.resume()
    lu.assertEquals(calls.inputBlocked, {})
    lu.assertEquals(calls.inputUnblocked, {})
end

function TestPauseState:testSlowModeUsesTheConfiguredFraction()
    logic.pause({ speedPercent = 40 })
    lu.assertAlmostEquals(calls.sim[1].args.Fraction, 0.4, 1e-9)
end

TestWatchdog = {}

function TestWatchdog:setUp()
    installGameStubs()
    logic.resume()
    -- Mirror the game: AddSimSpeedChange records the request in MapState.SimSpeedChanges.
    _G.MapState = { SimSpeedChanges = {} }
    _G.AddSimSpeedChange = function(name, args)
        calls.sim[#calls.sim + 1] = { name = name, args = args }
        _G.MapState.SimSpeedChanges[name] = args
    end
    _G.RemoveSimSpeedChange = function(name)
        if _G.MapState ~= nil then
            _G.MapState.SimSpeedChanges[name] = nil
        end
    end
end

function TestWatchdog:tearDown()
    logic.resume()
    clearGameStubs()
end

function TestWatchdog:testNothingToDoWhileTheFreezeIsIntact()
    logic.pause({ speedPercent = 0 })
    lu.assertFalse(logic.ensureApplied({ speedPercent = 0 }))
    lu.assertEquals(#calls.sim, 1)
end

function TestWatchdog:testFreezeIsReappliedWhenTheGameDropsIt()
    logic.pause({ speedPercent = 0 })
    _G.MapState.SimSpeedChanges = {} -- ClearSimSpeedChanges / a map-state reset

    lu.assertTrue(logic.ensureApplied({ speedPercent = 0 }))
    lu.assertEquals(#calls.sim, 2)
    lu.assertEquals(_G.MapState.SimSpeedChanges[logic.SIM_SPEED_NAME].Fraction, logic.MIN_FRACTION)
end

function TestWatchdog:testNothingHappensWhenNotPausedOrWithoutMapState()
    lu.assertFalse(logic.ensureApplied({ speedPercent = 0 }))

    logic.pause({ speedPercent = 0 })
    _G.MapState = nil
    lu.assertFalse(logic.ensureApplied({ speedPercent = 0 }))
end

function TestWatchdog:testReassertResendsTheSpeedOnlyWhilePaused()
    local updates = {}
    _G.UpdateSimulationSpeed = function(name, args)
        updates[#updates + 1] = { name = name, args = args }
    end
    lu.assertFalse(logic.reassert())

    logic.pause({ speedPercent = 0 })
    lu.assertTrue(logic.reassert())
    lu.assertEquals(#updates, 1)
    lu.assertEquals(updates[1].name, logic.SIM_SPEED_NAME)
    lu.assertEquals(updates[1].args.LerpTime, logic.LERP_TIME)
    _G.UpdateSimulationSpeed = nil
end

function TestWatchdog:testMeasureSpeedComparesWorldTimeToSystemTime()
    local speed = logic.measureSpeed({ system = 10, world = 100 }, { system = 11, world = 100.002 })
    lu.assertAlmostEquals(speed.worldPerSystem, 0.002, 1e-9)
    lu.assertAlmostEquals(speed.systemSeconds, 1, 1e-9)
    lu.assertNil(logic.measureSpeed(nil, { system = 1, world = 1 }))
    lu.assertNil(logic.measureSpeed({ system = 1 }, { system = 2 }).worldPerSystem)
end

function TestWatchdog:testSignatureListsEveryRequestAndReportsChangesOnce()
    logic.pause({ speedPercent = 0 })
    _G.MapState.SimSpeedChanges.WeaponHit = { Fraction = 0.1 }

    local changed, signature = logic.signatureChanged()
    lu.assertTrue(changed)
    lu.assertStrContains(signature, "WeaponHit=0.1")
    lu.assertStrContains(signature, logic.SIM_SPEED_NAME .. "=" .. tostring(logic.MIN_FRACTION))

    lu.assertFalse((logic.signatureChanged()))
    _G.MapState.SimSpeedChanges.WeaponHit = nil
    lu.assertTrue((logic.signatureChanged()))
end

TestStorage = {}

function TestStorage:testStorageShapeAndDefaults()
    local storage = data.buildStorage()
    local byAlias = {}
    for _, node in ipairs(storage) do
        byAlias[node.alias] = node
    end

    lu.assertNil(byAlias.EscapeToggle)
    lu.assertEquals(byAlias.Hotkey.default, "F9")
    lu.assertEquals(byAlias.SpeedPercent.default, 0)
    lu.assertEquals(byAlias.BlockInput.default, false)
    lu.assertEquals(byAlias.ShowIndicator.default, true)
end

function TestStorage:testHotkeyDefaultIsOfferedAsNone()
    lu.assertEquals(data.hotkeyValues[1], data.HOTKEY_NONE)
    lu.assertEquals(data.hotkeyDisplayValues[data.HOTKEY_NONE], "None")
end
