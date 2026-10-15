local data = {}

-- The pause key is a Lib-managed hotkey (module.hotkeys); its binding keeps the "Hotkey" storage
-- alias so saved bindings carry over.
data.HOTKEY_ID = "TogglePause"
data.HOTKEY_ALIAS = "Hotkey"
data.HOTKEY_DEFAULT = "F9"

data.speedPercent = {
    default = 0,
    min = 0,
    max = 90,
}

function data.buildStorage()
    return {
        {
            type = "int",
            alias = "SpeedPercent",
            default = data.speedPercent.default,
            min = data.speedPercent.min,
            max = data.speedPercent.max,
        },
        {
            type = "bool",
            alias = "BlockInput",
            default = false,
        },
        {
            type = "bool",
            alias = "ShowIndicator",
            default = true,
        },
    }
end

return data
