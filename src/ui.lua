local module = {}

local HOTKEY_TOOLTIP =
    "Key that toggles the freeze without opening the pause menu. Checked every frame while the "
    .. "Hell2Modding overlay is closed. It starts a freeze during plain gameplay only (not over boon "
    .. "screens, the codex or the trait tray, or while dead), and it can always end one."
local SPEED_TOOLTIP =
    "Game speed while paused, as a percentage of normal. 0 is a full freeze."
local INPUT_TOOLTIP =
    "Block attacks, dashes and other actions while paused so nothing queues up."
local INDICATOR_TOOLTIP = "Show a PAUSED badge in the top-left corner of the screen while paused."

function module.drawTab(draw, state, data)
    local widgets = draw.widgets
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
