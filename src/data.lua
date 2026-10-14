local data = {}

data.HOTKEY_NONE = ""
data.HOTKEY_DEFAULT = "F9"
-- F1 opens the Hell2Modding overlay, so it is not offered.
data.hotkeyValues = { data.HOTKEY_NONE, "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" }
data.hotkeyDisplayValues = { [data.HOTKEY_NONE] = "None" }

data.speedPercent = {
    default = 0,
    min = 0,
    max = 90,
}

function data.buildStorage()
    return {
        {
            type = "string",
            alias = "Hotkey",
            default = data.HOTKEY_DEFAULT,
            maxLen = 8,
        },
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
