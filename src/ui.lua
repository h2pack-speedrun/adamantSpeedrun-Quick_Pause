local module = {}

local SPEED_TOOLTIP =
    "Game speed while paused, as a percentage of normal. 0 is a full freeze."
local INPUT_TOOLTIP =
    "Block attacks, dashes and other actions while paused so nothing queues up."
local INDICATOR_TOOLTIP = "Show a PAUSED badge in the top-left corner of the screen while paused."

-- The pause key's picker is drawn by ModpackLib in the module header (module.hotkeys).
function module.drawTab(draw, state, data)
    local widgets = draw.widgets
    widgets.slider(state.get("SpeedPercent"), {
        label = "Speed while paused (%)",
        tooltip = SPEED_TOOLTIP,
        min = data.speedPercent.min,
        max = data.speedPercent.max,
        controlWidth = 220,
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
