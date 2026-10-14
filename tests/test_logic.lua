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
end

local function gameplayContext(overrides)
    local context = {
        baseBlocked = false,
        enabled = true,
        escapeToggle = true,
        shiftHeld = false,
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

TestDecideEscape = {}

function TestDecideEscape:testEscapeIsTakenOverDuringPlainGameplay()
    local decision = logic.decideEscape(gameplayContext())
    lu.assertTrue(decision.blocked)
    lu.assertTrue(decision.toggle)
end

function TestDecideEscape:testAlreadyBlockedPassesThroughUntouched()
    local decision = logic.decideEscape(gameplayContext({ baseBlocked = true }))
    lu.assertTrue(decision.blocked)
    lu.assertFalse(decision.toggle)
end

function TestDecideEscape:testShiftEscapeKeepsTheRealPauseMenu()
    local decision = logic.decideEscape(gameplayContext({ shiftHeld = true }))
    lu.assertFalse(decision.blocked)
    lu.assertFalse(decision.toggle)
end

function TestDecideEscape:testDisabledModuleOrOptionKeepsTheRealPauseMenu()
    lu.assertFalse(logic.decideEscape(gameplayContext({ enabled = false })).toggle)
    lu.assertFalse(logic.decideEscape(gameplayContext({ escapeToggle = false })).toggle)
end

function TestDecideEscape:testOpenScreensDeathAndNoRunKeepNormalBehaviour()
    lu.assertFalse(logic.decideEscape(gameplayContext({ openScreenCount = 1 })).toggle)
    lu.assertFalse(logic.decideEscape(gameplayContext({ handlingDeath = true })).toggle)
    lu.assertFalse(logic.decideEscape(gameplayContext({ hasRun = false })).toggle)
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

TestStorage = {}

function TestStorage:testStorageShapeAndDefaults()
    local storage = data.buildStorage()
    local byAlias = {}
    for _, node in ipairs(storage) do
        byAlias[node.alias] = node
    end

    lu.assertEquals(byAlias.EscapeToggle.default, true)
    lu.assertEquals(byAlias.Hotkey.default, "")
    lu.assertEquals(byAlias.SpeedPercent.default, 0)
    lu.assertEquals(byAlias.BlockInput.default, false)
    lu.assertEquals(byAlias.ShowIndicator.default, true)
end

function TestStorage:testHotkeyDefaultIsOfferedAsNone()
    lu.assertEquals(data.hotkeyValues[1], data.HOTKEY_NONE)
    lu.assertEquals(data.hotkeyDisplayValues[data.HOTKEY_NONE], "None")
end
