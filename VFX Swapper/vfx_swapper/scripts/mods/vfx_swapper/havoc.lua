local mod = get_mod("vfx_swapper")
local HavocBuffTemplates = require("scripts/settings/buff/havoc_buff_templates")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local minion_effects_priorities = BuffSettings.minion_effects_priorities
-- save start functions
local orig_enraged_start = HavocBuffTemplates.havoc_enraged_enemies.start_func
local orig_corrupted_start = HavocBuffTemplates.havoc_corrupted_enemies.start_func
local orig_toughened_skin_start = HavocBuffTemplates.havoc_toughened_skin.start_func

-- save stop functions
local orig_corrupted_stop = HavocBuffTemplates.havoc_corrupted_enemies.stop_func
-- save effects
local orig_enraged_effects = HavocBuffTemplates.havoc_enraged_enemies.minion_effects
local orig_garden_effects = HavocBuffTemplates.havoc_encroaching_garden.minion_effects
local orig_bolstering_effects = HavocBuffTemplates.havoc_bolstering.minion_effects
local orig_corrupted_effects = HavocBuffTemplates.havoc_corrupted_enemies.minion_effects
local orig_toughened_skin_effects = HavocBuffTemplates.havoc_toughened_skin.minion_effects

HavocBuffTemplates.havoc_corrupted_enemies.stop_func = function(template_data, template_context, ...)
    local unit = template_context.unit
    local position = POSITION_LOOKUP[unit]
    if not position or not Vector3.is_valid(position) then
        -- Still clear the material color (what the stop_func does before the server-only path)
        Unit.set_vector3_for_materials(unit, "stimmed_color", Vector3(0, 0, 0), true)
        return
    end
    return orig_corrupted_stop(template_data, template_context, ...)
end

local function unit_has_havoc_encroaching_garden(unit)
    local buff_ext = ScriptUnit.has_extension(unit, "buff_system")
    if not buff_ext then
        return false
    end

    local ok_t = buff_ext.has_buff_using_buff_template
    if not ok_t then
        return false
    end

    local has_t = ok_t(buff_ext, "havoc_encroaching_garden")

    if has_t then
        return true
    end
    
    return false
end


mod.havoc_enemy_vfx = function(self)
    if mod:get("disable_rampaging_vfx") then
        HavocBuffTemplates.havoc_bolstering.minion_effects = nil
    else 
        HavocBuffTemplates.havoc_bolstering.minion_effects = orig_bolstering_effects
    end
    
    if mod:get("disable_toughened_skin") then
		HavocBuffTemplates.havoc_toughened_skin.minion_effects.node_effects = nil
		HavocBuffTemplates.havoc_toughened_skin.start_func = function(template_data, template_context, ...)
            orig_toughened_skin_start(template_data, template_context, ...)
            local unit = template_context.unit
            local color = Vector3(0, 0, 0)
            Unit.set_vector3_for_materials(unit, "stimmed_color", color, true)
		end
    else
        HavocBuffTemplates.havoc_toughened_skin.minion_effects = orig_toughened_skin_effects
        HavocBuffTemplates.havoc_toughened_skin.start_func = orig_toughened_skin_start
    end
    
    if mod:get("disable_corrupted_enemies_vfx") then
        HavocBuffTemplates.havoc_corrupted_enemies.minion_effects.node_effects = nil
    else
        HavocBuffTemplates.havoc_corrupted_enemies.minion_effects = orig_corrupted_effects
    end
    if mod:get("disable_corrupted_enemies_color") then
        HavocBuffTemplates.havoc_corrupted_enemies.start_func = function(template_data, template_context, ...)
            orig_corrupted_start(template_data, template_context, ...)
            local unit = template_context.unit
            local color = Vector3(0, 0, 0)

            Unit.set_vector3_for_materials(unit, "stimmed_color", color, true)
        end
    else
        HavocBuffTemplates.havoc_corrupted_enemies.start_func = orig_corrupted_start
    end
    if mod:get("simple_havoc_color_vfx") then
        HavocBuffTemplates.havoc_enraged_enemies.start_func = function(template_data, template_context)
            -- Call the original to set the color via Unit.set_vector3_for_materials
            orig_enraged_start(template_data, template_context)

            -- Then override based on encroaching buff
            local unit = template_context.unit
            local is_pink = unit_has_havoc_encroaching_garden(unit)
            local my_color
            if is_pink then
                my_color = Vector3(1, 0.04, 0.2)
            else
                my_color = Vector3(1, 0, 0)
            end
            Unit.set_vector3_for_materials(unit, "stimmed_color", my_color, true)
        end
        -- remove the red glowing effect on head.
        HavocBuffTemplates.havoc_enraged_enemies.minion_effects.node_effects[1].vfx = nil
        HavocBuffTemplates.havoc_encroaching_garden.minion_effects.node_effects = {}

        HavocBuffTemplates.havoc_encroaching_garden.minion_effects.material_vector = {
            name = "stimmed_color",
            value = { 0.55, 0.08, 0.32 },  -- encroaching pink or close enough, really.
            priority = minion_effects_priorities.mutators + 1,
        }
    else 
        HavocBuffTemplates.havoc_enraged_enemies.start_func = orig_enraged_start
        HavocBuffTemplates.havoc_enraged_enemies.minion_effects = orig_enraged_effects
        HavocBuffTemplates.havoc_encroaching_garden.minion_effects = orig_garden_effects
    end
end



