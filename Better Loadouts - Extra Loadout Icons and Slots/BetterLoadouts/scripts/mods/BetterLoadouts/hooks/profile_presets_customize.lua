-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_customize.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local ProfileUtils = require("scripts/utilities/profile_utils")

mod:hook(CLASS.ViewElementProfilePresets, "on_profile_preset_index_customize", function(func, self, index)
    local result = func(self, index)

    if index then
        local profile_preset_id = self:_get_profile_preset_id_by_widget_index(index)
        local profile_preset = ProfileUtils.get_profile_preset(profile_preset_id)
        mod.sync_preset_customization_selection(self, profile_preset, "icon")

        local grid = self._profile_preset_tooltip_grid
        local widgets = grid and grid:widgets()
        if widgets then
            for i = 1, #widgets do
                local content = widgets[i].content
                if content and content.equipped then
                    grid:select_grid_widget(widgets[i])
                    break
                end
            end
        end
    end

    return result
end)
