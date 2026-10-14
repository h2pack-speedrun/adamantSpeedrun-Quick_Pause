local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
local reload = mods['SGG_Modding-ReLoad']
---@module "adamant-ModpackLib"
---@type AdamantModpackLib
local lib = mods['adamant-ModpackLib']

local PACK_ID = "speedrun"
local MODULE_ID = "Quick_Pause"
local PLUGIN_GUID = _PLUGIN.guid

local loader = reload.auto_single()

local function init()
    import_as_fallback(rom.game)
    local data = import("data.lua")
    local logic = import("logic.lua")
    local ui = import("ui.lua")

    local module = lib.createModule({
        pluginGuid = PLUGIN_GUID,
        id = MODULE_ID,
        name = "Quick Pause",
        shortName = "Quick Pause",
        tooltip = "Freeze or slow the game with a hotkey, without opening the pause menu.",
        hash = false,
        modpack = PACK_ID,
    })
    if not module then
        return
    end

    module.data.define(data.buildStorage())
    ui.attach(module, data)
    module.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)
    logic.attach(module, data)

    if not module.activate() then
        return
    end
end

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
