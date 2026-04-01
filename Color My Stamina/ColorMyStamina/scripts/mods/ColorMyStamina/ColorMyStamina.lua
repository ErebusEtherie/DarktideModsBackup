--[[
Title: Color My Stamina
Author: Miles
Date: 03/24/2026
Repository: https://github.com/Burzah/ColorMyStamina
Version: 1.0.0
--]]

local mod = get_mod("ColorMyStamina")
mod.version = "1.0.0"

local cached_thresholds = {}
local cached_default_rgba = {255, 0, 255, 0}

local function resolve_rgba(color_name)
    local color_func = Color[color_name] or Color["green"]
    local result = color_func(255, true)

    if type(result) == "table" then
        return {result[1] or 255, result[2] or 0, result[3] or 0, result[4] or 0}
    end
    local a, r, g, b = color_func(255, true)
    return {a or 255, r or 0, g or 0, b or 0}
end

local function rebuild_cache()
    local base_c = mod:get("base_color") or "green"

    local t1 = mod:get("threshold_1") or 100
    local t2 = mod:get("threshold_2") or 75
    local t3 = mod:get("threshold_3") or 50
    local t4 = mod:get("threshold_4") or 25

    local c1 = mod:get("color_1") or "green"
    local c2 = mod:get("color_2") or "yellow"
    local c3 = mod:get("color_3") or "orange"
    local c4 = mod:get("color_4") or "red"

    cached_thresholds = {
        {value = t1, rgba = resolve_rgba(c1)},
        {value = t2, rgba = resolve_rgba(c2)},
        {value = t3, rgba = resolve_rgba(c3)},
        {value = t4, rgba = resolve_rgba(c4)},
    }

    table.sort(cached_thresholds, function(a, b) return a.value < b.value end)
    cached_default_rgba = resolve_rgba(base_c)
end

mod.on_setting_changed = function()
    rebuild_cache()
end

mod.on_all_mods_loaded = function()
    rebuild_cache()
    mod:info(mod.version)
end

mod:hook("HudElementStamina", "_draw_stamina_chunks", function(func, self, dt, t, ui_renderer)
    if not func then
        return
    end

    if not mod:is_enabled() then
        return func(self, dt, t, ui_renderer)
    end

    local stamina_fraction = self._stamina_fraction or 0
    local parent = self._parent
    local player_extensions = parent and parent:player_extensions()

    if player_extensions then
        local player_unit_data = player_extensions.unit_data
        if player_unit_data then
            local ok, stamina_comp = pcall(player_unit_data.read_component, player_unit_data, "stamina")
            if ok and stamina_comp then
                stamina_fraction = stamina_comp.current_fraction or stamina_fraction
            end
        end
    end

    local percent = stamina_fraction * 100
    local rgba = cached_default_rgba

    for i = 1, #cached_thresholds do
        if percent <= cached_thresholds[i].value then
            rgba = cached_thresholds[i].rgba
            break
        end
    end

    local widget = self._widgets_by_name.stamina_bar
    if widget then
        if widget.style.bar_fill then
            local c = widget.style.bar_fill.color
            c[1], c[2], c[3], c[4] = rgba[1], rgba[2], rgba[3], rgba[4]
        end
        if widget.style.bar_spent then
            local sc = widget.style.bar_spent.color
            sc[1], sc[2], sc[3], sc[4] = 150, rgba[2], rgba[3], rgba[4]
        end
    end

    return func(self, dt, t, ui_renderer)
end)