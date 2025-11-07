

--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Health Scaling                                                                  │
│ Mod Description: Scales health and toughness bars based on their maximum values.          │
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]


local mod = get_mod("HealthScaling")



local tScale = 2.5
local tAnim = true
local tAnimSpeed = 2.5
local hScale = 5.0
local lScaling = true
local lScale = 10
local mBuffs = true
local mCoh = true


function mod.on_enabled(initial_call)
    tScale = mod:get("toughnessScale")
    tAnim = mod:get("toughnessAnimation")
    tAnimSpeed = mod:get("animationSpeed")
    hScale = mod:get("healthScale")
    lScale = mod:get("logScale")
    lScaling = mod:get("logScaling")
    mBuffs = mod:get("moveBuffs")
    mCoh = mod:get("moveCoherency")
end


function mod.on_setting_changed(setting_id)
    tScale = mod:get("toughnessScale")
    tAnim = mod:get("toughnessAnimation")
    tAnimSpeed = mod:get("animationSpeed")
    hScale = mod:get("healthScale")
    lScale = mod:get("logScale")
    lScaling = mod:get("logScaling")
    mBuffs = mod:get("moveBuffs")
    mCoh = mod:get("moveCoherency")
end

-- Check scale
local cScale = function(value, inverse)
    local z = (lScaling and math.log(value, lScale) or value)
    return inverse and (1-z) or z
end


local toughnessFraction = function(self, toughness_fraction, toughness_ghost_fraction, toughness_max_fraction, delta, player)
    if not self.fraction then self.fraction = toughness_max_fraction * tScale*(lScaling and 5 or 1) end
    if tAnim then 
        if self.fraction < toughness_max_fraction * tScale then
            self.fraction = self.fraction + delta * ((toughness_max_fraction * tScale*(lScaling and 5 or 1)) - self.fraction) * tAnimSpeed
        elseif self.fraction > toughness_max_fraction * tScale then
            self.fraction = self.fraction - delta * (self.fraction - (toughness_max_fraction * tScale*(lScaling and 5 or 1))) * tAnimSpeed
        end
    else
        self.fraction = toughness_max_fraction * tScale*(lScaling and 5 or 1)
    end
    local widgets_by_name = self._widgets_by_name
	local definitions = self._definitions
	local scenegraph_definition = definitions.scenegraph_definition
	local bar_width = scenegraph_definition.bar.size[1]
	-- if true then
        
    local toughness_ghost_id = "toughness_ghost"
    local toughness_bar_id = "toughness_bar_background"
    local toughness_text_id = "toughness_text"
    local bonus_toughness_text_id = "bonus_toughness_text"
    local toughness_ghost_widget = widgets_by_name[toughness_ghost_id]
    local toughness_bar_widget = widgets_by_name[toughness_bar_id]
    local toughness_text_widget = widgets_by_name[toughness_text_id]
    local bonus_toughness_text_widget = widgets_by_name[bonus_toughness_text_id]
    

    toughness_ghost_widget.style.texture.size[1] = bar_width * toughness_ghost_fraction * cScale(self.fraction)
    toughness_ghost_widget.dirty = true

    toughness_bar_widget.style.texture.size[1] = bar_width * cScale(self.fraction)
    toughness_bar_widget.dirty = true

    if toughness_text_widget then
        toughness_text_widget.style.text_1.offset[1] = 16 - (player and 279 or 179)*cScale(self.fraction, true)
        toughness_text_widget.style.text_2.offset[1] = 28 - (player and 279 or 179)*cScale(self.fraction, true)
        toughness_text_widget.style.text_3.offset[1] = 40 - (player and 279 or 179)*cScale(self.fraction, true)
        toughness_text_widget.style.text_1.offset[2] = player and 0 or -3
        toughness_text_widget.style.text_2.offset[2] = player and 0 or -3
        toughness_text_widget.style.text_3.offset[2] = player and 0 or -3
        toughness_text_widget.dirty = true
    end

    if bonus_toughness_text_widget then
        bonus_toughness_text_widget.style["text_1"].offset[1] = 10
        bonus_toughness_text_widget.style.style_id_1.offset[1] = 55 - 279*cScale(self.fraction, true)
        bonus_toughness_text_widget.dirty = true
    end
	-- end

    -- if toughness_fraction ~= self._toughness_fraction then
    local toughness_id = "toughness"
    local toughness_widget = widgets_by_name[toughness_id]
    toughness_widget.style.texture.size[1] = bar_width * toughness_fraction * cScale(self.fraction)
    toughness_widget.dirty = true
	-- end
end






local healthFraction

mod:hook_safe("HudElementPlayerBuffs", "_update_buff_alignments", function(s,...)
    if mBuffs then
        local active_buffs_data = s._active_buffs_data
        local num_active_buffs = #active_buffs_data 
        for i = 1, num_active_buffs do
            local buff_data = active_buffs_data[i]
            local widget = buff_data.widget
            if widget then widget.offset[2] = -60 end
        end
    end
end)





mod:hook_safe("HudElementPersonalPlayerPanel", "_update_player_features", function(s, dt, t, player, ui_renderer)
    local toughFraction = s._max_toughness/(lScaling and 350 or 240.0)
    toughnessFraction(s, s._toughness_fraction, s._toughness_ghost_fraction, toughFraction, dt, true)
    if s._overshield_amount < 100 then
        s._widgets_by_name.bonus_toughness_text.style["text_1"].offset[1] = 75 - 279*cScale(s.fraction, true)
    else
        s._widgets_by_name.bonus_toughness_text.style["text_1"].offset[1] = 82 - 279*cScale(s.fraction, true)
    end

    local healthFraction = s._max_health / (lScaling and 350 or 240)
    s._widgets_by_name.health_text.style.text_1.offset[1] = -279 + 16 + 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction)
    s._widgets_by_name.health_text.style.text_2.offset[1] = -279 + 28 + 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction)
    s._widgets_by_name.health_text.style.text_3.offset[1] = -279 + 40 + 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction)
end)

mod:hook_safe("HudElementTeamPlayerPanel", "_update_player_features", function(s, dt, t, player, ui_renderer)
    local toughFraction = s._max_toughness/(lScaling and 284 or 161.5)
    toughnessFraction(s, s._toughness_fraction, s._toughness_ghost_fraction, toughFraction, dt)
    if s._widgets_by_name.bonus_toughness_text then
        if s._overshield_amount and s._overshield_amount < 100 then
            s._widgets_by_name.bonus_toughness_text.style["text_1"].offset[1] = 75 - 279*cScale(s.fraction, true)
        else
            s._widgets_by_name.bonus_toughness_text.style["text_1"].offset[1] = 82 - 279*cScale(s.fraction, true)
        end
    end
    if s._widgets_by_name.health_text then
        local healthFraction = s._max_health / (lScaling and 400 or 250)
        s._widgets_by_name.health_text.style.text_1.offset[1] = 116 - 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction, true)
        s._widgets_by_name.health_text.style.text_2.offset[1] = 128 - 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction, true)
        s._widgets_by_name.health_text.style.text_3.offset[1] = 140 - 279*cScale(hScale*(lScaling and 5 or 1)*healthFraction, true)
        s._widgets_by_name.health_text.style.text_1.offset[2] = player and 0 or -3
        s._widgets_by_name.health_text.style.text_2.offset[2] = player and 0 or -3
        s._widgets_by_name.health_text.style.text_3.offset[2] = player and 0 or -3
    end
end)



mod:hook("HudElementPersonalPlayerPanel", "scenegraph_size", function(f,s,...)
    local x = f(s,...)
    if not s._knocked_down then x[1] = 279*cScale(hScale*(lScaling and 5 or 1)*s._max_health / (lScaling and 350 or 240))
    else x[1] = 279 end
    return x
end)

mod:hook("HudElementTeamPlayerPanel", "scenegraph_size", function(f,s,...)
    local x = f(s,...)
    if not s._knocked_down then x[1] = 279*cScale(hScale*(lScaling and 5 or 1)*s._max_health / (lScaling and 400 or 250))
    else x[1] = 279 end
    return x
end)

mod:hook_safe("HudElementTeamPlayerPanel", "_update_coherency", function(s, ...)
    if mCoh then
        s._widgets_by_name.coherency_indicator.style.texture.offset[1] = 30
        s._widgets_by_name.coherency_indicator.style.texture.offset[2] = -30
    end
end)









-- mod:hook_safe(CLASS.HudElementBossHealth, "update", function (self, dt, t, ui_renderer, render_settings, input_service)
--     local is_active = self._is_active

-- 	if not is_active then
-- 		return
-- 	end

--     local widget_groups = self._widget_groups
-- 	local active_targets_array = self._active_targets_array
-- 	local num_active_targets = #active_targets_array

-- 	for i = 1, num_active_targets do
-- 		local widget_group_index = num_active_targets > 1 and i + 1 or i
-- 		local widget_group = widget_groups[widget_group_index]
-- 		local target = active_targets_array[i]
-- 		local unit = target.unit

--         if ALIVE[unit] then

--             local widget = widget_group.health
--             local color = color_by_unit(unit)
--             widget.style.bar.color = color
--             widget.style.max.color = color
--             widget.style.text.text_color = color

--             local numeric_UI_widget = widget_group.health_text
--             if numeric_UI_widget then
--                 numeric_UI_widget.style.text.text_color = color
--             end
--         end
--     end
-- end)