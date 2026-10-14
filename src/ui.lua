local module = {}

local ESCAPE_TOOLTIP =
    "Escape freezes or slows the game instead of opening the pause menu. Only during plain gameplay: "
    .. "it does nothing over boon screens, the codex, the trait tray, or while you are dead. "
    .. "Hold Shift and press Escape to open the real pause menu."
local HOTKEY_TOOLTIP =
    "Optional key that toggles the freeze, checked every frame while the Hell2Modding overlay is closed. "
    .. "Works during plain gameplay only."
local SPEED_TOOLTIP =
    "Game speed while paused, as a percentage of normal. 0 is a full freeze."
local INPUT_TOOLTIP =
    "Block attacks, dashes and other actions while paused so nothing queues up. Leave off if pausing "
    .. "stops Escape from unpausing."
local INDICATOR_TOOLTIP = "Show a PAUSED line in the lower centre of the screen while paused."

function module.drawTab(draw, state, data)
    local widgets = draw.widgets
    widgets.checkbox(state.get("EscapeToggle"), {
        label = "Escape pauses without the menu",
        tooltip = ESCAPE_TOOLTIP,
    })
    widgets.dropdown(state.get("Hotkey"), {
        label = "Pause hotkey",
        tooltip = HOTKEY_TOOLTIP,
        values = data.hotkeyValues,
        displayValues = data.hotkeyDisplayValues,
        controlWidth = 140,
    })
    widgets.stepper(state.get("SpeedPercent"), {
        label = "Speed while paused (%)",
        tooltip = SPEED_TOOLTIP,
        min = data.speedPercent.min,
        max = data.speedPercent.max,
        step = 5,
    })
    widgets.checkbox(state.get("BlockInput"), {
        label = "Block actions while paused",
        tooltip = INPUT_TOOLTIP,
    })
    widgets.checkbox(state.get("ShowIndicator"), {
        label = "Show PAUSED indicator",
        tooltip = INDICATOR_TOOLTIP,
    })
end

function module.attach(libModule, data)
    libModule.ui.tab(function(_, ui)
        return module.drawTab(ui.draw, ui.data, data)
    end)
end

return module
